module MiGA::DistanceRunner::Commands
  ##
  # Estimates AAI against +targets+ using hAAI
  def haai(targets)
    puts "[#{Time.now}] hAAI: #{dataset.name} vs #{targets.size} targets"
    empty_vals = targets.map { |_i| nil }
    return empty_vals if opts[:haai_p] == 'no'

    # Launch comparisons
    sbj = pending_targets(targets, :haai)
    unless sbj.empty?
      opts[:haai_p] == 'fastaai' ? fastaai_cmd(sbj) : haai_cmd(sbj)
    end

    # Return AAI estimates from the database
    batch_values_from_db(:aai, targets.map { |i| i&.name })
  end

  ##
  # Estimates or calculates AAI against +targets+
  def aai(targets)
    puts "[#{Time.now}] AAI: #{dataset.name} vs #{targets.size} targets"

    # Try hAAI first
    haai(targets)

    # Launch comparisons
    pending_targets(targets, :aai).each do |target|
      # Full AAI
      target_cds = target.result(:cds).file_path(:proteins) or next
      aairb_cmd(
        tmp_file('proteins.fa'), target_cds,
        dataset.name, target.name, tmp_dbs[:aai], checkpoint: :aai
      )
    end

    # Return AAI from the database
    batch_values_from_db(:aai, targets.map { |i| i&.name })
  end

  ##
  # Calculates ANI against +targets+
  def ani(targets)
    puts "[#{Time.now}] ANI: #{dataset.name} vs #{targets.size} targets"
    empty_vals = targets.map { |_i| nil }
    return empty_vals unless File.size?(tmp_file('largecontigs.fa'))

    # Launch comparisons
    sbj = pending_targets(targets, :ani)
    unless sbj.empty?
      opts[:ani_p] == 'fastani' ? fastani_cmd(sbj) : anirb_cmd(sbj)
    end

    # Return ANI from the database
    batch_values_from_db(:ani, targets.map { |i| i&.name })
  end

  ##
  # Calculates and returns ANI against +targets+ if AAI >= +aai_limit+.
  # Note that ANI values may be returned for lower (or failing) AAIs if the
  # value is already stored in the database
  def ani_after_aai(targets, aai_limit = 85.0)
    # Run AAI and select targets with AAI ≥ aai_limit
    aai = aai(targets)
    sbj = aai.each_with_index.map { |i, k| targets[k] if i&.> aai_limit }
    sbj.compact!

    # Run ANI
    ani(sbj) unless sbj.empty?

    # Return ANI from the database
    batch_values_from_db(:ani, targets.map { |i| i&.name })
  end

  ##
  # Execute an AAI command
  def aairb_cmd(f1, f2, n1, n2, db, o = {})
    o = opts.merge(o)
    run_cmd <<~CMD
              aai.rb -1 "#{f1}" -2 "#{f2}" -S "#{db}" \
              --name1 "#{n1}" --name2 "#{n2}" \
              -t "#{o[:thr]}" -a --#{'no-' unless o[:aai_save_rbm]}save-rbm \
              -p "#{o[:aai_p]}"
            CMD
  ensure
    checkpoint(o[:checkpoint]) if o[:checkpoint]
  end

  ##
  # Execute an ani.rb command
  def anirb_cmd(targets)
    f1 = tmp_file('largecontigs.fa')
    return unless File.size?(f1)

    targets.each do |target|
      target_asm = target&.result(:assembly)&.file_path(:largecontigs) or next
      run_cmd <<~CMD
                ani.rb -1 "#{f1}" -2 "#{target_asm}" -S "#{tmp_dbs[:ani]}" \
                --name1 "#{dataset.name}" --name2 "#{target.name}" \
                -t "#{opts[:thr]}" -a --no-save-regions --no-save-rbm \
                -p "#{opts[:ani_p]}"
              CMD
      checkpoint(:ani)
    end
  end

  ##
  # Execute a FastANI command
  def fastani_cmd(targets)
    f1 = tmp_file('largecontigs.fa')
    return unless File.size?(f1)

    # Run FastANI
    File.open(f2 = tmp_file, 'w') do |fh|
      targets.each do |target|
        target_asm = target&.result(:assembly)&.file_path(:largecontigs)
        fh.puts target_asm if target_asm
      end
    end
    run_cmd <<~CMD
              fastANI -q "#{f1}" --rl "#{f2}" -t #{opts[:thr]} \
              -o "#{f3 = tmp_file}"
            CMD

    # Retrieve resulting data and save to DB
    data = {}
    File.open(f3, 'r') do |fh|
      fh.each do |ln|
        row = ln.chomp.split("\t")
        n2 = File.basename(row[1], '.gz')
        n2 = File.basename(n2, '.LargeContigs.fna')
        data[n2] = [row[2].to_f, 0.0, row[3].to_i, row[4].to_i]
      end
    end
    batch_data_to_db(:ani, data)

    # Cleanup
    [f2, f3].each { |i| File.unlink(i) }
  end

  ##
  # Execute a FastAAI command
  def fastaai_cmd(targets)
    qry_idx = dataset.result(:essential_genes).file_path(:fastaai_index_2)
    return nil unless qry_idx

    # Merge databases
    donors = []
    targets.each do |target|
      tgt_idx = target&.result(:essential_genes)&.file_path(:fastaai_index_2)
      donors << tgt_idx if tgt_idx
    end
    return nil if donors.empty?

    # Build target database
    File.open(f0 = tmp_file, 'w') { |fh| donors.each { |i| fh.puts i } }
    run_cmd <<~CMD
              FastAAI merge_db --donor_file "#{f0}" \
                --recipient "#{f1 = tmp_file}" --threads #{opts[:thr]}
            CMD

    # Run FastAAI
    run_cmd <<~CMD
              FastAAI db_query --query "#{qry_idx}" --target "#{f1}" \
                --output "#{f2 = tmp_file}" --threads #{opts[:thr]} \
                --do_stdev
            CMD

    # Save values in the databases
    haai_data = {}
    aai_data = {}
    # Ugly workaround to the insistence of FastAAI not to provide the files
    # I ask for ;-)
    qry_results = File.basename(qry_idx, '.faix') + '_results.txt'
    out_file = File.join(f2, 'results', qry_results)
    File.open(out_file, 'r') do |fh|
      fh.each do |ln|
        out = ln.chomp.split("\t")
        haai_data[out[1]] = [
          out[2].to_f * 100, out[3].to_f * 100, out[4].to_i, out[5].to_i
        ]
        out[6] = (out[6] =~ /^>/) ? 95.0 : out[6].to_f
        aai_data[out[1]] = [out[6], 0, 0, 0]
      end
    end
    puts "Results: #{haai_data.size} | Inferences: #{aai_data.size}"
    batch_data_to_db(:haai, haai_data)
    batch_data_to_db(:aai, aai_data)

    # Cleanup
    [f1, f2].each { |i| FileUtils.rm_r(i) }
  end

  ##
  # Execute an hAAI command
  def haai_cmd(targets)
    aai_data = {}
    targets.each do |target|
      target_ess = target&.result(:essential_genes)&.file_path(:ess_genes)
      next unless target_ess

      # hAAI
      h = aairb_cmd(
            tmp_file('ess_genes.fa'), target_ess,
            dataset.name, target.name, tmp_dbs[:haai],
            aai_save_rbm: false, aai_p: opts[:haai_p], checkpoint: :haai
          )&.chomp&.to_f
      next if h.nil? || h.zero? || h > 90.0

      # Estimated AAI
      aai_data[target.name] = [
        100.0 - Math.exp(2.435076 + 0.4275193 * Math.log(100.0 - h)), 0, 0, 0
      ] unless h&.zero? || h > 90.0
    end
    batch_data_to_db(:aai, aai_data)
  end

  def run_cmd(cmd)
    puts "CMD: #{cmd}"
    `#{cmd}`
  end
end
