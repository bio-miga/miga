
require_relative 'base.rb'
require_relative 'temporal.rb'
require_relative 'database.rb'
require_relative 'commands.rb'
require_relative 'pipeline.rb'


class MiGA::DistanceRunner

  include MiGA::DistanceRunner::Temporal
  include MiGA::DistanceRunner::Database
  include MiGA::DistanceRunner::Commands
  include MiGA::DistanceRunner::Pipeline

  attr_reader :project, :ref_project, :dataset, :opts, :home
  attr_reader :tmp, :tmp_dbs, :dbs, :db_counts

  def initialize(project_path, dataset_name, opts_hash={})
    @opts = opts_hash
    @project = MiGA::Project.load(project_path) or
      raise "No project at #{project_path}"
    @dataset = project.dataset(dataset_name)
    @home = File.expand_path('data/09.distances', project.path)
    # Default opts
    @opts[:aai_save_rbm] ||= ENV.fetch('MIGA_AAI_SAVE_RBM') do
      project.is_clade? ? 'save-rbm' : 'no-save-rbm'
    end
    @opts[:thr] ||= ENV.fetch('CORES'){ 2 }.to_i
    if opts[:run_taxonomy] and project.metadata[:ref_project]
      ref_path = project.metadata[:ref_project]
      @home = File.expand_path('05.taxonomy', @home)
      @ref_project = MiGA::Project.load(ref_path)
      raise "Cannot load reference project: #{ref_path}" if @ref_project.nil?
    elsif !opts[:run_taxonomy] and dataset.metadata[:db_project]
      ref_path = dataset.metadata[:db_project]
      if project.metadata[:db_proj_dir]
        ref_path = File.expand_path(ref_path, project.metadata[:db_proj_dir])
      end
      @ref_project = MiGA::Project.load(ref_path)
      raise "Cannot load reference project: #{ref_path}" if @ref_project.nil?
    else
      @ref_project = project
    end
    [:haai_p, :aai_p, :ani_p, :distances_checkpoint].each do |m|
      @opts[m] ||= ref_project.metadata[m]
    end
    @opts[:distances_checkpoint] ||= 10
    @opts[:distances_checkpoint] = @opts[:distances_checkpoint].to_i
  end

  # Launch the appropriate analysis
  def go!
    return if dataset.is_multi?
    Dir.mktmpdir do |tmp_dir|
      @tmp = tmp_dir
      create_temporals
      opts[:run_taxonomy] ? go_taxonomy! : dataset.is_ref? ? go_ref! : go_query!
    end
  end

  # Launch analysis for reference datasets
  def go_ref!
    # Initialize databases
    initialize_dbs! true

    # first-come-first-serve traverse
    ref_project.each_dataset do |ds|
      next if !ds.is_ref? or ds.is_multi? or ds.result(:essential_genes).nil?
      puts "[ #{Time.now} ] #{ds.name}"
      ani_after_aai(ds)
    end

    # Finalize
    [:haai, :aai, :ani].each{ |m| checkpoint! m if db_counts[m] > 0 }
  end

  ##
  # Launch analysis for query datasets
  def go_query!
    # Check if project is ready
    tsk = ref_project.is_clade? ? [:subclades, :ani] : [:clade_finding, :aai]
    res = ref_project.result(tsk[0])
    return if res.nil?

    # Initialize the databases
    initialize_dbs! false
    # Calculate the classification-informed AAI/ANI traverse
    results = File.expand_path("#{dataset.name}.#{tsk[1]}-medoids.tsv", home)
    fh = File.open(results, 'w')
    classif, val_cls = *classify(res.dir, '.', tsk[1], fh)
    fh.close

    # Calculate all the AAIs/ANIs against the lowest subclade (if classified)
    par_dir = File.dirname(File.expand_path(classif, res.dir))
    par = File.expand_path('miga-project.classif', par_dir)
    closest = {dataset: nil, ani: 0.0}
    if File.size? par
      File.open(par, 'r') do |fh|
        fh.each_line do |ln|
          r = ln.chomp.split("\t")
          next unless r[1].to_i == val_cls
          ani = ani_after_aai(ref_project.dataset(r[0]), 80.0)
          closest = {ds: r[0], ani: ani} unless ani.nil? or ani < closest[:ani]
        end
      end
    end

    # Calculate all the AAIs/ANIs against the closest ANI95-clade (if AAI > 80%)
    cl_path = res.file_path :clades_ani95
    if File.size? cl_path and tsk[0] == :clade_finding
      File.foreach(cl_path).
        map  { |i| i.chomp.split(',') }.
        find( lambda{[]} ){ |i| i.include? closest[:ds] }.
        each { |i| ani_after_aai(ref_project.dataset(i), 80.0) }
    end

    # Finalize
    [:haai, :aai, :ani].each{ |m| checkpoint! m if db_counts[m] > 0 }
    build_medoids_tree(tsk[1])
    transfer_taxonomy(tax_test)
  end

  # Launch analysis for taxonomy jobs
  def go_taxonomy!
    return unless project.metadata[:ref_project]
    go_query! # <- yeah, it's actually the same, just different ref_project
  end
end
