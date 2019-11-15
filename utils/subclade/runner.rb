
require_relative 'base.rb'
require_relative 'temporal.rb'
require_relative 'pipeline.rb'

class MiGA::SubcladeRunner

  include MiGA::SubcladeRunner::Temporal
  include MiGA::SubcladeRunner::Pipeline

  attr_reader :project, :step, :opts, :home, :tmp

  def initialize(project_path, step, opts_hash={})
    @opts = opts_hash
    @project = MiGA::Project.load(project_path) or
          raise "No project at #{project_path}"
    @step = step.to_sym
    clades_dir = File.expand_path('data/10.clades', project.path)
    @home = File.expand_path(@step == :clade_finding ? '01.find' : '02.ani',
          clades_dir)
    @opts[:thr] ||= ENV.fetch('CORES') { 2 }.to_i
    @opts[:run_clades] = @project.metadata.data.fetch(:run_clades) { true }
  end

  # Launch the appropriate analysis
  def go!
    return if project.type == :metagenomes
    unless @project.dataset_names.any? { |i| @project.dataset(i).is_ref? }
      FileUtils.touch(File.expand_path('miga-project.empty', @home))
      return
    end
    Dir.chdir home
    Dir.mktmpdir do |tmp_dir|
      @tmp = tmp_dir
      create_temporals
      step == :clade_finding ? go_clade_finding! : go_subclades!
    end
  end

  # Launch analysis for clade_finding
  def go_clade_finding!
    cluster_species
    unless project.is_clade?
      subclades :aai
      compile
    end
  end

  # Launch analysis for subclades
  def go_subclades!
    subclades :ani
    compile
  end

end
