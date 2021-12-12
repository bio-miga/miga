# High-end pipelines for DistanceRunner
module MiGA::DistanceRunner::Pipeline
  # Recursively classify the dataset, returning an Array with two entries:
  # classification and cluster number
  def classify(clades, classif, metric, result_fh, val_cls = nil)
    dir = File.expand_path(classif, clades)
    med = File.expand_path('miga-project.medoids', dir)
    return [classif, val_cls] unless File.size? med

    max_val = 0
    val_med = ''
    val_cls = nil
    i_n = 0
    sbj_datasets = File.foreach(med).map { |i| ref_project.dataset(i.chomp) }
    values = send(metric, sbj_datasets)
    max_idx = values.map(&:to_f).each_with_index.max[1]
    max_val = values[max_idx]
    val_med = sbj_datasets[max_idx].name
    val_cls = max_idx + 1
    puts "[#{classif}] New max: #{val_med} (#{val_cls}): #{max_val}"

    classif = "#{classif}/miga-project.sc-#{val_cls}"
    result_fh.puts [val_cls, val_med, max_val, classif].join("\t")
    classify(clades, classif, metric, result_fh, val_cls)
  end

  # Run distances against datasets listed in metadata's +:dist_req+
  def distances_by_request(metric)
    $stderr.puts 'Running distances by request'
    sbj_datasets = dataset.option(:dist_req).map { |i| ref_project.dataset(i) }
    send(metric, sbj_datasets)
  end

  # Builds a tree with all visited medoids from any classification level
  def build_medoids_tree(metric)
    # TODO Reduce impact and bring back the medoids tree
    $stderr.puts 'Bypassing medoids tree'
    return

    $stderr.puts "Building medoids tree (metric = #{metric})"
    db = query_db(metric)
    return unless File.size? db

    out_base = File.expand_path(dataset.name, home)
    ds_matrix = "#{out_base}.txt"
    ds_matrix_fh = File.open(ds_matrix, 'w')
    ds_matrix_fh.puts %w[a b value].join("\t")
    # Find all values in the database
    seq2 = []
    foreach_in_db(db, metric) do |r|
      seq2 << r[0]
      ds_matrix_fh.puts r[0, 3].join("\t")
    end
    # Find all values among visited datasets in ref_project
    ref_r = ref_project.result("#{metric}_distances") or return
    Zlib::GzipReader.open(ref_r.file_path(:matrix)) do |fh|
      fh.each_line do |ln|
        r = ln.chomp.split("\t")
        next unless seq2.include?(r[1]) or seq2.include?(r[2])

        ds_matrix_fh.puts r[1, 3].join("\t")
      end
    end
    ds_matrix_fh.close
    ref_tree = File.join(MiGA::MiGA.root_path, 'utils', 'ref-tree.R')
    MiGA::MiGA.run_cmd([ref_tree, ds_matrix, out_base, dataset.name])
    File.unlink(ds_matrix)
  end

  # Tests taxonomy
  def tax_test
    $stderr.puts "Testing taxonomy | opts = #{opts}"
    # Get taxonomy of closest relative
    from_ref_project = (project != ref_project)
    res_dir =
      from_ref_project ?
        File.expand_path('data/09.distances/05.taxonomy', project.path) :
        home
    Dir.mkdir res_dir unless Dir.exist? res_dir
    File.open(File.expand_path("#{dataset.name}.done", res_dir), 'w') do |fh|
      fh.puts Time.now.to_s
    end
    dataset.add_result(from_ref_project ? :taxonomy : :distances, true)
    cr = dataset.closest_relatives(1, from_ref_project)
    return if cr.nil? or cr.empty?

    tax = ref_project.dataset(cr[0][0]).metadata[:tax] || {}

    # Run the test for each rank
    tax_test = MiGA::TaxDist.aai_pvalues(cr[0][1], :intax, engine: opts[:aai_p])
    r = tax_test.map do |k, v|
      sig = ''
      [0.5, 0.1, 0.05, 0.01].each { |i| sig << '*' if v < i }
      [MiGA::Taxonomy.LONG_RANKS[k], (tax[k] || '?'), v, sig]
    end

    # Save test
    File.open(File.expand_path("#{dataset.name}.intax.txt", home), 'w') do |fh|
      fh.puts "Closest relative: #{cr[0][0]} with AAI: #{cr[0][1]}."
      fh.puts ''
      fh.puts MiGA::MiGA.tabulate(%w[Rank Taxonomy P-value Signif.], r)
      fh.puts ''
      fh.puts 'Significance at p-value below: *0.5, **0.1, ***0.05, ****0.01.'
    end
    return r
  end

  # Transfer the taxonomy to the current dataset
  def transfer_taxonomy(tax)
    $stderr.puts 'Transferring taxonomy'
    return if tax.nil?

    pval = project.option(:tax_pvalue)
    tax_a = tax
            .select { |i| i[1] != '?' && i[2] <= pval }
            .map { |i| i[0, 2].join(':') }
    dataset.metadata[:tax] = MiGA::Taxonomy.new(tax_a)
    dataset.save
  end
end
