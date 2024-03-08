# frozen_string_literal: true

require 'miga/remote_dataset'
module MiGA::Cli::Action::Download
end

##
# Helper module including download functions for the *_get actions
module MiGA::Cli::Action::Download::Base
  def cli_base_flags(opt)
    opt.on(
      '--max-download INT', Integer,
      'Maximum number of datasets to download (by default: unlimited)'
    ) { |v| cli[:max_datasets] = v }
    opt.on(
      '-m', '--metadata STRING',
      'Metadata as key-value pairs separated by = and delimited by comma',
      'Values are saved as strings except for booleans (true / false) or nil'
    ) { |v| cli[:metadata] = v }
  end

  def cli_filters(opt)
    opt.on(
      '--exclude PATH',
      'A file with dataset names to exclude'
    ) { |v| cli[:exclude] = v }
    cli.opt_flag(opt, 'dry', 'Do not download or save the datasets')
    opt.on(
      '--ignore-until STRING',
      'Ignores all datasets until a name is found (useful for large reruns)'
    ) { |v| cli[:ignore_until] = v }
    opt.on(
      '--ignore-removed',
      'Ignores entries removed from NCBI (by default fails on removed entries)'
    ) { |v| cli[:ignore_removed] = v }
    cli.opt_flag(
      opt, 'get-metadata',
      'Only download and update metadata for existing datasets', :get_md
    )
    opt.on(
      '--updated-before DATE',
      'Only download metadata for datasets last updated before the given date',
      'Requires --get-metadata, supports date or date-time'
    ) { |v| cli[:updated_before] = DateTime.parse(v) }
  end

  def cli_save_actions(opt)
    cli.opt_flag(
      opt, 'only-metadata',
      'Create datasets without input data but retrieve all metadata',
      :only_md
    )
    opt.on(
      '--save-every INT', Integer,
      'Save project every this many downloaded datasets',
      'If zero, it saves the project only once upon completion',
      "By default: #{cli[:save_every]}"
    ) { |v| cli[:save_every] = v }
    opt.on(
      '-q', '--query',
      'Register the datasets as queries, not reference datasets'
    ) { |v| cli[:query] = v }
    opt.on(
      '-u', '--unlink',
      'Unlink all datasets in the project missing from the download list'
    ) { |v| cli[:unlink] = v }
    opt.on(
      '-R', '--remote-list PATH',
      'Path to an output file with the list of all datasets listed remotely'
    ) { |v| cli[:remote_list] = v }
    opt.on(
      '--ncbi-taxonomy-dump [path]',
      'Path to an NCBI Taxonomy dump directory to query instead of API calls',
      'If the path is not passed, the dump is automatically downloaded'
    ) { |v| cli[:ncbi_taxonomy_dump] = v || true }
  end

  def generic_perform
    p, ds = load_tasks
    d, downloaded = download_entries(ds, p)

    # Finalize
    finalize_tasks(d, downloaded)
    unlink_entries(p, p.dataset_names - d) if cli[:unlink]
  end

  def load_tasks
    sanitize_cli
    p = cli.load_project
    load_ncbi_taxonomy_dump
    ds = remote_list
    ds = discard_excluded(ds)
    ds = exclude_newer(ds)
    ds = impose_limit(ds)
    [p, ds]
  end

  def load_ncbi_taxonomy_dump
    return unless cli[:ncbi_taxonomy_dump]

    if cli[:ncbi_taxonomy_dump] == true
      cli.say 'Downloading and reading NCBI Taxonomy dump'
      Dir.mktmpdir do |dir|
        file = 'taxdump.tar.gz'
        path = File.join(dir, file)
        url  = 'https://ftp.ncbi.nih.gov/pub/taxonomy/%s' % file
        
        File.open(path, 'wb') { |fh| fh.print MiGA::MiGA.net_method(:get, url) }
        MiGA::MiGA.run_cmd('cd "%s" && tar -zxf "%s"' % [dir, file])
        MiGA::RemoteDataset.use_ncbi_taxonomy_dump(dir, cli)
      end
    else
      cli.say "Reading NCBI Taxonomy dump: #{cli[:ncbi_taxonomy_dump]}"
      MiGA::RemoteDataset.use_ncbi_taxonomy_dump(cli[:ncbi_taxonomy_dump], cli)
    end
  end


  def finalize_tasks(d, downloaded)
    cli.say "Datasets listed: #{d.size}"
    act = cli[:dry] ? 'to download' : 'downloaded'
    cli.say "Datasets #{act}: #{downloaded}"
    unless cli[:remote_list].nil?
      File.open(cli[:remote_list], 'w') do |fh|
        d.each { |i| fh.puts i }
      end
    end
  end

  def unlink_entries(p, unlink)
    unlink.each { |i| p.unlink_dataset(i).remove! }
    cli.say "Datasets unlinked: #{unlink.size}"
  end

  def discard_excluded(ds)
    unless cli[:exclude].nil?
      cli.say "Discarding datasets in #{cli[:exclude]}"
      File.readlines(cli[:exclude])
          .select { |i| i !~ /^#/ }
          .map(&:chomp)
          .each { |i| ds.delete i }
    end
    ds
  end

  def exclude_newer(ds)
    return ds unless cli[:updated_before]

    project = cli.load_project
    ds.select do |name|
      d = project.dataset(name)
      d && DateTime.parse(d.metadata[:updated]) < cli[:updated_before]
    end
  end

  def impose_limit(ds)
    max = cli[:max_datasets].to_i
    if !max.zero? && max < ds.size
      cli.say "Subsampling list from #{ds.size} to #{max} datasets"
      sample = ds.keys.sample(max)
      ds.select! { |k, _| sample.include? k }
    end
    ds
  end

  def download_entries(ds, p)
    cli.say "Downloading #{ds.size} " + (ds.size == 1 ? 'entry' : 'entries')
    p.do_not_save = true if cli[:save_every] != 1
    ignore = !cli[:ignore_until].nil?
    downloaded = 0
    d = []
    ds.each do |name, body|
      d << name
      cli.puts name
      ignore = false if ignore && name == cli[:ignore_until]
      next if ignore || p.dataset(name).nil? == cli[:get_md]

      downloaded += 1
      unless cli[:dry]
        unless save_entry(name, body, p)
          downloaded -= 1
          d.pop
          next
        end
        p.save! if cli[:save_every] > 1 && (downloaded % cli[:save_every]).zero?
      end
    end
    p.do_not_save = false
    p.save! if cli[:save_every] != 1
    [d, downloaded]
  end

  ##
  # Saves the (generic remote) entry identified by +name+ with +body+ into the
  # project +p+, and returns +true+ on success and +false+ otherwise
  def save_entry(name, body, p)
    cli.say "  Locating remote dataset: #{name}"
    body[:md][:metadata_only] = true if cli[:only_md]
    rd = MiGA::RemoteDataset.new(body[:ids], body[:db], body[:universe])
    if cli[:get_md]
      cli.say '  Updating dataset'
      rd.update_metadata(p.dataset(name), body[:md])
    else
      cli.say '  Creating dataset'
      rd.save_to(p, name, !cli[:query], body[:md])
      cli.add_metadata(p.add_dataset(name))
    end
    true
  rescue MiGA::RemoteDataMissingError => e
    raise(e) unless cli[:ignore_removed]
    cli.say "    Removed dataset ignored: #{name}"
    false
  end
end
