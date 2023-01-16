
module MiGA::Cli::Action::Doctor::Operations
  ##
  # Perform status operation with MiGA::Cli +cli+
  def check_status(cli)
    cli.say 'Updating metadata status'
    p = cli.load_project
    n = p.dataset_names.size
    (0 .. cli[:threads] - 1).map do |i|
      Process.fork do
        k = 0
        cli.load_project.each_dataset do |d|
          k += 1
          cli.advance('Datasets:', k, n, false) if i == 0
          d.recalculate_status if k % cli[:threads] == i
        end
      end
    end
    Process.waitall
    cli.say
  end

  # check_db in Distances

  # check_bidir in Distances

  # check_dist in Distances

  ##
  # Perform files operation with MiGA::Cli +cli+
  def check_files(cli)
    cli.say 'Looking for outdated files in results'
    n, k = cli.load_project.dataset_names.size, 0
    cli.load_project.each_dataset do |d|
      cli.advance('Datasets:', k += 1, n, false)
      d.each_result do |r_k, r|
        ok = true
        r.each_file do |_f_sym, _f_rel, f_abs|
          unless File.exist? f_abs
            ok = false
            break
          end
        end
        unless ok
          cli.say "  > Registering again #{d.name}:#{r_k}   "
          d.add_result(r_k, true, force: true)
          sr = d.result(:stats) and sr.remove!
        end
      end
    end
    cli.say
  end

  ##
  # Perform cds operation with MiGA::Cli +cli+
  def check_cds(cli)
    cli.say 'Looking for unzipped genes or proteins'
    n, k = cli.load_project.dataset_names.size, 0
    cli.load_project.each_dataset do |d|
      cli.advance('Datasets:', k += 1, n, false)
      res = d.result(:cds) or next
      changed = false
      %i[genes proteins gff3 gff2 tab].each do |f|
        file = res.file_path(f) or next
        if file !~ /\.gz/
          cli.say "  > Gzipping #{d.name} #{f}   "
          run_cmd(['gzip', '-9', file])
          changed = true
        end
      end
      if changed
        d.add_result(:cds, true, force: true)
        sr = d.result(:stats) and sr.remove!
      end
    end
    cli.say
  end

  ##
  # Perform essential-genes operation with MiGA::Cli +cli+
  def check_ess(cli)
    cli.say 'Looking for outdated essential genes'
    cli.load_project.each_dataset do |d|
      res = d.result(:essential_genes)
      next if res.nil?

      dir = res.file_path(:collection)
      if dir.nil? || outdated_fastaai_ess(res)
        cli.say "  > Removing #{d.name}:essential_genes"
        res.remove!
        d.result(:stats)&.remove!
        next
      end
      next if Dir["#{dir}/*.faa"].empty?

      cli.say "  > Fixing #{d.name}"
      run_cmd <<~CMD
        cd #{dir.shellescape} && tar -zcf proteins.tar.gz *.faa && rm *.faa
      CMD
    end
  end

  ##
  # Perform mytaxa-scan operation with MiGA::Cli +cli+
  def check_mts(cli)
    cli.say 'Looking for unarchived MyTaxa Scan runs'
    cli.load_project.each_dataset do |d|
      res = d.result(:mytaxa_scan)
      next if res.nil?

      dir = res.file_path(:regions)
      fix = false
      unless dir.nil?
        if Dir.exist? dir
          run_cmd <<~CMD
            cd #{dir.shellescape}/.. \
                && tar -zcf '#{d.name}.reg.tar.gz' '#{d.name}.reg' \
                && rm -r '#{d.name}.reg'
          CMD
        end
        fix = true
      end
      %i[blast mytaxain wintax gene_ids region_ids].each do |ext|
        file = res.file_path(ext)
        unless file.nil?
          FileUtils.rm(file) if File.exist? file
          fix = true
        end
      end
      if fix
        cli.say "  > Fixing #{d.name}"
        d.add_result(:mytaxa_scan, true, force: true)
      end
    end
  end

  ##
  # Perform start operation with MiGA::Cli +cli+
  def check_start(cli)
    cli.say 'Looking for legacy .start files lingering'
    cli.load_project.each_dataset do |d|
      d.each_result do |r_k, r|
        if File.exist? r.path(:start)
          cli.say "  > Registering again #{d.name}:#{r_k}"
          r.save
        end
      end
    end
  end

  ##
  # Perform taxonomy operation with MiGA::Cli +cli+
  def check_tax(cli)
    # cli.say 'o Checking for taxonomy/distances consistency'
    # TODO: Find 95%ANI clusters with entries from different species
    # TODO: Find different 95%ANI clusters with genomes from the same species
    # TODO: Find AAI values too high or too low for each LCA rank
  end
end
