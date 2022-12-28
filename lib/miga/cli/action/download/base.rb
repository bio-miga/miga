# frozen_string_literal: true

require 'miga/remote_dataset'
module MiGA::Cli::Action::Download
end

##
# Helper module including download functions for the *_get actions
module MiGA::Cli::Action::Download::Base
  def cli_filters(opt)
    opt.on(
      '--blacklist PATH',
      'A file with dataset names to blacklist'
    ) { |v| cli[:blacklist] = v }
    cli.opt_flag(opt, 'dry', 'Do not download or save the datasets')
    opt.on(
      '--ignore-until STRING',
      'Ignores all datasets until a name is found (useful for large reruns)'
    ) { |v| cli[:ignore_until] = v }
    cli.opt_flag(
      opt, 'get-metadata',
      'Only download and update metadata for existing datasets', :get_md
    )
  end

  def cli_save_actions(opt)
    cli.opt_flag(
      opt, '--only-metadata',
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

  def discard_blacklisted(ds)
    unless cli[:blacklist].nil?
      cli.say "Discarding datasets in #{cli[:blacklist]}"
      File.readlines(cli[:blacklist])
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
        save_entry(name, body, p)
        p.save! if cli[:save_every] > 1 && (downloaded % cli[:save_every]).zero?
      end
    end
    p.do_not_save = false
    p.save! if cli[:save_every] != 1
    [d, downloaded]
  end

  def save_entry(name, body, p)
    cli.say '  Locating remote dataset'
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
  end
end
