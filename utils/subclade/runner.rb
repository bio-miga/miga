
require_relative 'base.rb'

class MiGA::SubcladeRunner
  attr_reader(:project, :step, :opts, :home, :tmp)

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
    %i[run_clades gsp_ani gsp_aai gsp_metric indexing].each do |m|
      @opts[m] = @project.option(m)
    end
  end

  # Launch the appropriate analysis
  def go!
    return if project.type == :metagenomes

    if @opts[:indexing] == 'no' ||
          !@project.dataset_names.any? { |i| @project.dataset(i).ref? }
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
    unless project.clade?
      subclades(:aai)
      compile
    end
  end

  # Launch analysis for subclades
  def go_subclades!
    subclades(:ani)
    compile
  end
end
