
require 'tmpdir'

module MiGA::DistanceRunner::Temporal

  # Copy input files to the (local) temporal folder
  def create_temporals
    rf = {essential_genes: :ess_genes, cds: :proteins, assembly: :largecontigs}
    rf.each do |res, file|
      r = dataset.result(res)
      f = r.nil? ? nil : r.file_path(file)
      FileUtils.cp(f, tmp_file("#{file}.fa")) unless f.nil?
    end
  end

  # Temporal file with extension +ext+
  def tmp_file(ext)
    File.expand_path("#{dataset.name}.#{ext}", tmp)
  end

  # Copies temporal databases back to the MiGA Project if 10 or more values
  # have been stored without copying
  def checkpoint(metric)
    @db_counts[metric] += 1
    checkpoint! metric if db_counts[metric] >= 10
  end

  # Copies temporal databases back to the MiGA Project
  def checkpoint!(metric)
    SQLite3::Database.new(tmp_dbs[metric]) do |conn|
      conn.execute("select count(*) from #{metric==:haai ? :aai : metric}")
    end
    FileUtils.cp(tmp_dbs[metric], dbs[metric])
    @db_counts[metric] = 0
  end
end
