require_relative 'base.rb'
require_relative 'temporal.rb'
require_relative 'pipeline.rb'

class MiGA::SubcladeRunner
  include MiGA::SubcladeRunner::Temporal
  include MiGA::SubcladeRunner::Pipeline

  attr_reader :project, :step, :opts, :home, :tmp

  def initialize(project_path, step, opts_hash = {})
    @opts = opts_hash
    @project = MiGA::Project.load(project_path) or
      raise "No project at #{project_path}"
    @step = step.to_sym
    @home = File.join(
      File.join(project.path, 'data', '10.clades'),
      @step == :clade_finding ? '01.find.running' : '02.ani.running'
    )
    @opts[:thr] ||= ENV.fetch('CORES') { 2 }.to_i
    @opts[:run_clades] = @project.option(:run_clades)
    @opts[:gsp_ani] = @project.option(:gsp_ani)
    @opts[:gsp_aai] = @project.option(:gsp_aai)
    @opts[:gsp_metric] = @project.option(:gsp_metric)
  end

  # Launch the appropriate analysis
  def go!
    return if project.type == :metagenomes

    unless @project.dataset_names.any? { |i| @project.dataset(i).is_ref? }
      FileUtils.touch(File.join(@home, 'miga-project.empty'))
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
