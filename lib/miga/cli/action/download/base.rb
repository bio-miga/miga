# frozen_string_literal: true

require 'miga/remote_dataset'
module MiGA::Cli::Action::Download
end

##
# Helper module including download functions for the *_get actions
module MiGA::Cli::Action::Download::Base
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
    ds = remote_list
    ds = discard_excluded(ds)
    ds = impose_limit(ds)
    [p, ds]
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
