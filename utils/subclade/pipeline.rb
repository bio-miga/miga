# High-end pipelines for SubcladeRunner
module MiGA::SubcladeRunner::Pipeline
  # Run species-level clusterings using ANI > 95% / AAI > 90%
  def cluster_species
    tasks = {
      ani95: [:ani_distances, opts[:gsp_ani], :ani],
      aai90: [:aai_distances, opts[:gsp_aai], :aai]
    }
    tasks.each do |k, par|
      # Run only the requested metric
      next unless par[2].to_s == opts[:gsp_metric]

      # Final output
      ogs_file = "miga-project.#{k}-clades"
      next if File.size?(ogs_file)

      # Build ABC files
      abc_path = tmp_file("#{k}.abc")
      ofh = File.open(abc_path, 'w')
      metric_res = project.result(par[0]) or raise "Incomplete step #{par[0]}"
      Zlib::GzipReader.open(metric_res.file_path(:matrix)) do |ifh|
        ifh.each_line do |ln|
          next if ln =~ /^a\tb\tvalue\t/

          r = ln.chomp.split("\t")
          ofh.puts("G>#{r[0]}\tG>#{r[1]}\t#{r[2]}") if r[2].to_f >= par[1]
        end
      end
      ofh.close
      # Cluster genomes
      if File.size? abc_path
        `ogs.mcl.rb -o '#{ogs_file}.tmp' --abc '#{abc_path}' -t '#{opts[:thr]}'`
        File.open(ogs_file, 'w') do |fh|
          File.foreach("#{ogs_file}.tmp").with_index do |ln, lno|
            fh.puts(ln) if lno > 0
          end
        end
        File.unlink "#{ogs_file}.tmp"
      else
        FileUtils.touch(ogs_file)
      end
      FileUtils.cp(ogs_file, 'miga-project.gsp-clades')
    end

    # Find genomospecies medoids
    src = File.expand_path('utils/find-medoid.R', MiGA::MiGA.root_path)
    dir = opts[:gsp_metric] == 'aai' ? '02.aai' : '03.ani'
    `Rscript '#{src}' '../../09.distances/#{dir}/miga-project.rds' \
      miga-project.gsp-medoids miga-project.gsp-clades`
    if File.exist? 'miga-project.gsp-clades.sorted'
      File.rename 'miga-project.gsp-clades.sorted', 'miga-project.gsp-clades'
    end

    # Propose clades
    ofh = File.open('miga-project.proposed-clades', 'w')
    File.open('miga-project.gsp-clades', 'r') do |ifh|
      ifh.each_line do |ln|
        r = ln.chomp.split(',')
        ofh.puts r.join("\t") if r.size >= 5
      end
    end
    ofh.close
  end

  def subclades metric
    src = File.expand_path('utils/subclades.R', MiGA::MiGA.root_path)
    step = :"#{metric}_distances"
    metric_res = project.result(step) or raise "Incomplete step #{step}"
    matrix = metric_res.file_path(:matrix)
    `Rscript '#{src}' '#{matrix}' miga-project '#{opts[:thr]}' \
      miga-project.gsp-medoids '#{opts[:run_clades] ? 'cluster' : 'empty'}'`
    if File.exist? 'miga-project.nwk'
      File.rename('miga-project.nwk', "miga-project.#{metric}.nwk")
    end
  end

  def compile
    src = File.expand_path('utils/subclades-compile.rb', MiGA::MiGA.root_path)
    `ruby '#{src}' '.' 'miga-project.class'`
  end
end
