
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
    @opts[:thr] ||= ENV.fetch("CORES"){ 2 }.to_i
    if opts[:run_taxonomy] && project.metadata[:ref_project]
      @home = File.expand_path('05.taxonomy', @home)
      @ref_project = MiGA::Project.load(project.metadata[:ref_project])
    end
    @ref_project ||= project
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
      aai = aai(ds)
      ani(ds) unless aai.nil? or aai < 90.0
    end
    # Finalize
    [:haai, :aai, :ani].each{ |m| checkpoint! m if db_counts[m] > 0 }
  end

  # Launch analysis for query datasets
  def go_query!
    # Check if project is ready
    v = ref_project.is_clade? ? [:subclades, :ani] : [:clade_finding, :aai]
    res = ref_project.result(v[0])
    return if res.nil?
    # Initialize the databases
    initialize_dbs! false
    # Calculate the classification-informed AAI/ANI traverse
    results = File.expand_path("#{dataset.name}.#{v[1]}-medoids.tsv", home)
    fh = File.open(results, "w")
    classif, val_cls = *classify(res.dir, ".", v[1], fh)
    fh.close
    # Calculate all the AAIs/ANIs against the lowest subclade (if classified)
    par_dir = File.dirname(File.expand_path(classif, res.dir))
    par = File.expand_path("miga-project.classif", par_dir)
    if File.size? par
      File.open(par, "r") do |fh|
        fh.each_line do |ln|
          r = ln.chomp.split("\t")
          next unless r[1].to_i==val_cls
          target = ref_project.dataset(r[0])
          aai = (v[1]==:aai) ? aai(target) : 100.0
          ani(target) if aai >= 90.0
        end
      end
    end
    # Finalize
    [:haai, :aai, :ani].each{ |m| checkpoint! m if db_counts[m] > 0 }
    build_medoids_tree(v[1])
    transfer_taxonomy(tax_test)
  end

  # Launch analysis for taxonomy jobs
  def go_taxonomy!
    return unless project.metadata[:ref_project]
    go_query! # <- yeah, it's actually the same, just different ref_project
  end
end
