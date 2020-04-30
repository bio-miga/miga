# @package MiGA
# @license Artistic-2.0

require 'miga/cli/action'
require 'rubygems/package'

class MiGA::Cli::Action::Archive < MiGA::Cli::Action
  def parse_cli
    cli.parse do |opt|
      opt.on(
        '-o', '--tarball PATH',
        '(Mandatory) Path to the archive to be created ending in .tar.gz'
      ) { |v| cli[:tarball] = v }
      opt.on(
        '-f', '--folder STRING',
        'Name of the output folder. By default: name of the source project'
      ) { |v| cli[:folder] = v }
      cli.opt_object(opt, [:project, :dataset_opt])
      cli.opt_filter_datasets(opt)
    end
  end

  def perform
    cli.ensure_par(tarball: '-o')
    unless cli[:tarball] =~ /\.tar\.gz$/
      raise 'The tarball path (-o) must have .tar.gz extension'
    end

    cli[:folder] ||= cli.load_project.name
    ds = cli.load_and_filter_datasets

    open_tarball do |tar|
      # Datasets
      cli.say 'Archiving datasets'
      each_file_listed(ds) do |rel_path, abs_path|
        add_file_to_tar(tar, rel_path, abs_path)
      end

      # Project
      cli.say 'Archiving project'
      pmd = cli.load_project.metadata.dup
      pmd[:datasets] = ds.map(&:name)
      add_string_to_tar(tar, 'miga.project.json', pmd.to_json)
      add_string_to_tar(tar, 'daemon/daemon.json', '{}')
    end
  end

  private

  def open_tarball(&blk)
    File.open(cli[:tarball], 'wb') do |fh|
      Zlib::GzipWriter.wrap(fh) do |gz|
        Gem::Package::TarWriter.new(gz) do |tar|
          blk.call(tar)
        end
      end
    end
  end

  def each_file_listed(datasets, &blk)
    datasets.each_with_index do |ds, k|
      cli.advance('Datasets:', k + 1, datasets.size, false)
      # Metadata
      blk.call(
        File.join('metadata', File.basename(ds.metadata.path)),
        ds.metadata.path
      )
      # Results
      ds.each_result do |sym, res|
        res.each_file do |_sym, rel_path, abs_path|
          blk.call(File.join(res.relative_dir, rel_path), abs_path)
        end
        blk.call(res.relative_path, res.path) # <- JSON
      end
    end
    cli.say
  end

  def add_file_to_tar(tar, rel_path, abs_path)
    if File.directory? abs_path
      Dir["#{abs_path}/*"].each do |f|
        add_file_to_tar(tar, File.join(rel_path, File.basename(f)), f)
      end
    else
      in_tar = File.join(cli[:folder], rel_path)
      tar.add_file_simple(in_tar, 0666, File.size(abs_path)) do |ofh|
        File.open(abs_path, 'rb') do |ifh|
          ofh.write(ifh.read(1024)) until ifh.eof?
        end
      end
    end
  end

  def add_string_to_tar(tar, rel_path, string)
    in_tar = File.join(cli[:folder], rel_path)
    tar.add_file_simple(in_tar, 0666, string.size) { |fh| fh.write(string) }
  end
end
