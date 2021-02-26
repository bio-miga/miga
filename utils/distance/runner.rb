require_relative 'base.rb'

class MiGA::DistanceRunner
  attr_reader :project, :ref_project, :dataset, :opts, :home
  attr_reader :tmp, :tmp_dbs, :dbs, :db_counts

  def initialize(project_path, dataset_name, opts_hash = {})
    @opts = opts_hash
    @project = MiGA::Project.load(project_path)
    @project or raise "No project at #{project_path}"
    @dataset = project.dataset(dataset_name)
    @home = File.expand_path('data/09.distances', project.path)

    # Default opts
    if opts[:run_taxonomy] && project.option(:ref_project)
      ref_path = project.option(:ref_project)
      @home = File.expand_path('05.taxonomy', @home)
      @ref_project = MiGA::Project.load(ref_path)
      raise "Cannot load reference project: #{ref_path}" if @ref_project.nil?
    elsif !opts[:run_taxonomy] && dataset.option(:db_project)
      ref_path = dataset.option(:db_project)
      if project.option(:db_proj_dir)
        ref_path = File.expand_path(ref_path, project.option(:db_proj_dir))
      end
      @ref_project = MiGA::Project.load(ref_path)
      raise "Cannot load reference project: #{ref_path}" if @ref_project.nil?
    else
      @ref_project = project
    end
    @opts[:thr] ||= ENV.fetch('CORES') { 1 }.to_i
    %i[haai_p aai_p ani_p distances_checkpoint aai_save_rbm].each do |m|
      @opts[m] ||= ref_project.option(m)
    end
    $stderr.puts "Options: #{opts}"
  end

  # Launch the appropriate analysis
  def go!
    $stderr.puts "Launching analysis"
    return if dataset.multi?

    Dir.mktmpdir do |tmp_dir|
      @tmp = tmp_dir
      create_temporals
      opts[:run_taxonomy] ? go_taxonomy! : dataset.ref? ? go_ref! : go_query!
    end
  end

  # Launch analysis for reference datasets
  def go_ref!
    $stderr.puts 'Launching analysis for reference dataset'
    # Initialize databases
    initialize_dbs! true

    # first-come-first-serve traverse
    sbj = []
    ref_project.each_dataset do |ds|
      sbj << ds if ds.ref? && !ds.multi? && ds.result(:essential_genes)
    end
    ani_after_aai(sbj)

    # Finalize
    %i[haai aai ani].each { |m| checkpoint! m if db_counts[m] > 0 }
  end

  ##
  # Launch analysis for query datasets
  def go_query!
    $stderr.puts 'Launching analysis for query dataset'
    # Check if project is ready
    tsk = ref_project.clade? ? [:subclades, :ani] : [:clade_finding, :aai]
    res = ref_project.result(tsk[0])
    return if res.nil?

    # Initialize the databases
    initialize_dbs! false
    distances_by_request(tsk[1])
    # Calculate the classification-informed AAI/ANI traverse
    results = File.expand_path("#{dataset.name}.#{tsk[1]}-medoids.tsv", home)
    fh = File.open(results, 'w')
    classif, val_cls = *classify(res.dir, '.', tsk[1], fh)
    fh.close

    # Calculate all the AAIs/ANIs against the lowest subclade (if classified)
    par_dir = File.dirname(File.expand_path(classif, res.dir))
    par = File.expand_path('miga-project.classif', par_dir)
    closest = { dataset: nil, ani: 0.0 }
    sbj_datasets = []
    if File.size? par
      File.open(par, 'r') do |fh|
        fh.each_line do |ln|
          r = ln.chomp.split("\t")
          sbj_datasets << ref_project.dataset(r[0]) if r[1].to_i == val_cls
        end
      end
      ani = ani_after_aai(sbj_datasets, 80.0)
      ani_max = ani.map(&:to_f).each_with_index.max
      closest = { ds: sbj_datasets[ani_max[1]].name, ani: ani_max[0] }
    end

    # Calculate all the AAIs/ANIs against the closest ANI95-clade (if AAI > 80%)
    cl_path = res.file_path :clades_ani95
    if !cl_path.nil? && File.size?(cl_path) && tsk[0] == :clade_finding
      clades = File.foreach(cl_path).map { |i| i.chomp.split(',') }
      sbj_dataset_names = clades.find { |i| i.include?(closest[:ds]) }
      sbj_datasets = sbj_dataset_names&.map { |i| ref_project.dataset(i) }
      ani_after_aai(sbj_datasets, 80.0) if sbj_datasets
    end

    # Finalize
    [:haai, :aai, :ani].each { |m| checkpoint! m if db_counts[m] > 0 }
    build_medoids_tree(tsk[1])
    transfer_taxonomy(tax_test)
  end

  # Launch analysis for taxonomy jobs
  def go_taxonomy!
    $stderr.puts 'Launching taxonomy analysis'
    return unless project.option(:ref_project)

    go_query! # <- yeah, it's actually the same, just different ref_project
  end
end
