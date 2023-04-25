require 'tmpdir'
require 'zlib'

module MiGA::DistanceRunner::Temporal
  # Copy input files to the (local) temporal folder
  def create_temporals
    rf = {
      essential_genes: :ess_genes,
      cds: :proteins,
      assembly: :largecontigs
    }
    rf.each do |res, file|
      r = dataset.result(res)
      f = r.nil? ? nil : r.file_path(file)
      unless f.nil?
        if f =~ /\.gz/
          File.open(tmp_file("#{file}.fa"), 'w') do |ofh|
            Zlib::GzipReader.open(f) { |ifh| ofh.print ifh.read }
          end
        else
          FileUtils.cp(f, tmp_file("#{file}.fa"))
        end
      end
    end
  end

  # Temporal file with extension +ext+, or a unique ID if +ext+ is +nil+
  def tmp_file(ext = nil)
    @_tmp_count ||= 0
    ext ||= "#{@_tmp_count += 1}.tmp"
    File.expand_path("#{dataset.name}.#{ext}", tmp)
  end

  # Copies temporal databases back to the MiGA Project if 10 or more values
  # have been stored without copying. The period (10 by default) can be
  # controlled using +@opts[:distances_checkpoint]+
  def checkpoint(metric)
    @db_counts[metric] += 1
    checkpoint! metric if db_counts[metric] >= @opts[:distances_checkpoint]
  end

  # Copies temporal databases back to the MiGA Project
  def checkpoint!(metric)
    return if opts[:only_domain]
    $stderr.puts "Checkpoint (metric = #{metric})"

    # This is simply to test database consistency before overwriting the
    # previous persistent version
    SQLite3::Database.new(tmp_dbs[metric]) do |conn|
      conn.execute("select count(*) from #{metric == :haai ? :aai : metric}")
    end

    # This reduces the probability of other threads failing due to incomplete
    # databases, +cp+ can be slower, and that effect is increased by the fact
    # that tmp_dbs -> dbs could involve a transfer between filesystems, whereas
    # +move+ within the same filesystem is nearly instantaenous
    FileUtils.cp(tmp_dbs[metric], "#{dbs[metric]}.tmp")
    FileUtils.move("#{dbs[metric]}.tmp", dbs[metric])
    @db_counts[metric] = 0
  end
end
