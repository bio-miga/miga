module MiGA::DistanceRunner::Commands
  # Estimates or calculates AAI against +target+
  def aai(target)
    # Check if the request makes sense
    return nil if target.nil? || target.result(:essential_genes).nil?

    # Check if it's been calculated
    y = stored_value(target, :aai)
    return y unless y.nil? || y.zero?

    # Try hAAI (except in clade projects)
    unless @ref_project.is_clade?
      y = haai(target)
      return y unless y.nil? || y.zero?
    end
    # Full AAI
    aai_cmd(
      tmp_file('proteins.fa'), target.result(:cds).file_path(:proteins),
      dataset.name, target.name, tmp_dbs[:aai]
    ).tap { checkpoint :aai }
  end

  ##
  # Estimates AAI against +target+ using hAAI
  def haai(target)
    return nil if opts[:haai_p] == 'no'

    haai = aai_cmd(tmp_file('ess_genes.fa'),
                   target.result(:essential_genes).file_path(:ess_genes),
                   dataset.name, target.name, tmp_dbs[:haai],
                   aai_save_rbm: 'no-save-rbm', aai_p: opts[:haai_p])
    checkpoint :haai
    return nil if haai.nil? || haai.zero? || haai > 90.0

    aai = 100.0 - Math.exp(2.435076 + 0.4275193 * Math.log(100.0 - haai))
    SQLite3::Database.new(tmp_dbs[:aai]) do |conn|
      conn.execute 'insert into aai values(?, ?, ?, 0, 0, 0)',
                   [dataset.name, target.name, aai]
    end
    checkpoint :aai
    aai
  end

  ##
  # Estimates AAI against +targets+ in batch using kAAI
  def batch_kaai(targets)
    # Lists of databases
    list1 = tmp_file('kaai_list_1.txt')
    File.open(list1, 'w') do |fh|
      fh.puts dataset.result(:essential_genes).file_path(:kaai_db)
    end
    list2 = tmp_file('kaai_list_2.txt')
    File.open(list2, 'w') do |fh|
      targets
        .map { |d| d.result(:essential_genes).file_path(:kaai_db) }
        .compact.each { |i| fh.puts i }
    end

    # Run kAAI
    out = tmp_file('kaai_out.txt')
    `kAAI_v1.0.py --qd "#{list1}" --rd "#{list2}" \
      -t "#{opts[:thr]}" -o "#{out}"`

    # Save results in the database
    File.open(out, 'r') do |fh|
      kaai_conn = SQLite3::Database.new(tmp_dbs[:haai])
      aai_conn  = SQLite3::Database.new(tmp_dbs[:aai])
      fh.each do |ln|
        row = ln.chomp.split("\t")
        row[2] = row[2].to_f * 100
        kaai_conn.execute('insert into aai values(?, ?, ?, 0, ?, ?)', row)
        next if row[2] > 90 # Maximum kAAI value with valid transformation
        p = [-0.3087057, 1.810741, -0.2607023, 3.435] # kAAI -> AAI parameters
        row[2] = p[0] + p[1] * (Math.exp(-(p[3] * Math.log(row[2]))**(1.0/p[4])))
        aai_conn.execute('insert into aai values(?, ?, ?, 0, ?, ?)', row)
      end
      kaai_conn.close
      aai_conn.close
      checkpoint :haai
      checkpoint :aai
    end
  end

  ##
  # Calculates ANI against +target+
  def ani(target)
    # Check if the request makes sense
    t = tmp_file('largecontigs.fa')
    r = target.result(:assembly)
    return nil if r.nil? || !File.size?(t)

    # Check if it's been calculated
    y = stored_value(target, :ani)
    return y unless y.nil? || y.zero?

    # Run it
    ani_cmd(
      t, r.file_path(:largecontigs),
      dataset.name, target.name, tmp_dbs[:ani]
    ).tap { checkpoint :ani }
  end

  ##
  # Calculates and returns ANI against +target+ if AAI >= +aai_limit+.
  # Returns +nil+ otherwise
  def ani_after_aai(target, aai_limit = 85.0)
    aai = aai(target)
    (aai.nil? || aai < aai_limit) ? nil : ani(target)
  end

  ##
  # Execute an AAI command
  def aai_cmd(f1, f2, n1, n2, db, o = {})
    o = opts.merge(o)
    v = `aai.rb -1 "#{f1}" -2 "#{f2}" -S "#{db}" \
          --name1 "#{n1}" --name2 "#{n2}" \
          -t "#{o[:thr]}" -a --lookup-first "--#{o[:aai_save_rbm]}" \
          -p "#{o[:aai_p] || 'blast+'}"`.chomp
    (v.nil? || v.empty?) ? 0 : v.to_f
  end

  ##
  # Execute an ANI command
  def ani_cmd(f1, f2, n1, n2, db, o = {})
    o = opts.merge(o)
    v = nil
    if o[:ani_p] == 'fastani'
      out = `fastANI -r "#{f1}" -q "#{f2}" \
            -o /dev/stdout 2>/dev/null`.chomp.split(/\s+/)
      unless out.empty?
        SQLite3::Database.new(db) do |conn|
          conn.execute 'insert into ani values(?, ?, ?, 0, ?, ?)',
                       [n1, n2, out[2], out[3], out[4]]
        end
      end
      v = out[2]
    else
      v = `ani.rb -1 "#{f1}" -2 "#{f2}" -S "#{db}" \
            --name1 "#{n1}" --name2 "#{n2}" \
            -t "#{opts[:thr]}" -a --no-save-regions --no-save-rbm \
            --lookup-first -p "#{o[:ani_p] || 'blast+'}"`.chomp
    end
    v.nil? || v.empty? ? 0 : v.to_f
  end
end
