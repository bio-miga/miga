# @package MiGA
# @license Artistic-2.0

require "miga/result"
require "miga/project/base"

##
# Helper module including specific functions to add project results.
module MiGA::Project::Result

  include MiGA::Project::Base
  
  ##
  # Get result identified by Symbol +name+, returns MiGA::Result.
  def result(name)
    dir = @@RESULT_DIRS[name.to_sym]
    return nil if dir.nil?
    MiGA::Result.load("#{path}/data/#{dir}/miga-project.json")
  end

  ##
  # Get all results, an Array of MiGA::Result.
  def results
    @@RESULT_DIRS.keys.map{ |k| result(k) }.reject{ |r| r.nil? }
  end
  
  ##
  # Add the result identified by Symbol +name+, and return MiGA::Result. Save
  # the result if +save+. The +opts+ hash controls result creation (if
  # necessary).
  # Supported values include:
  # - +force+: A Boolean indicating if the result must be re-indexed. If true,
  #   it implies save=true.
  def add_result(name, save=true, opts={})
    return nil if @@RESULT_DIRS[name].nil?
    base = "#{path}/data/#{@@RESULT_DIRS[name]}/miga-project"
    if opts[:force]
      FileUtils.rm("#{base}.json") if File.exist?("#{base}.json")
    else
      r_pre = MiGA::Result.load("#{base}.json")
      return r_pre if (r_pre.nil? and not save) or not r_pre.nil?
    end
    r = result_files_exist?(base, ".done") ?
        send("add_result_#{name}", base) : nil
    r.save unless r.nil?
    r
  end
  
  ##
  # Get the next distances task, saving intermediate results if +save+. Returns
  # a Symbol.
  def next_distances(save=true) ; next_task(@@DISTANCE_TASKS, save) ; end
  
  ##
  # Get the next inclade task, saving intermediate results if +save+. Returns a
  # Symbol.
  def next_inclade(save=true) ; next_task(@@INCLADE_TASKS, save) ; end

  ##
  # Get the next task from +tasks+, saving intermediate results if +save+.
  # Returns a Symbol.
  def next_task(tasks=@@DISTANCE_TASKS+@@INCLADE_TASKS, save=true)
    tasks.find do |t|
      if metadata["run_#{t}"]==false or
            (!is_clade? and @@INCLADE_TASKS.include?(t) and
                  metadata["run_#{t}"]!=true)
        false
      else
        add_result(t, save).nil?
      end
    end
  end
  
  
  private

    ##
    # Internal alias for all add_result_*_distances.
    def add_result_distances(base)
      return nil unless result_files_exist?(base, %w[.Rdata .log .txt])
      r = MiGA::Result.new("#{base}.json")
      r.add_file(:rdata, "miga-project.Rdata")
      r.add_file(:matrix, "miga-project.txt")
      r.add_file(:log, "miga-project.log")
      r.add_file(:hist, "miga-project.hist")
      r
    end

    def add_result_clade_finding(base)
      return nil unless result_files_exist?(base, %w[.proposed-clades])
      return nil unless is_clade? or result_files_exist?(base,
        %w[.pdf .classif .medoids .class.tsv .class.nwk])
      r = add_result_iter_clades(base)
      r.add_file(:aai_tree,	"miga-project.aai.nwk")
      r.add_file(:proposal,	"miga-project.proposed-clades")
      r.add_file(:clades_aai90,	"miga-project.aai90-clades")
      r.add_file(:clades_ani95,	"miga-project.ani95-clades")
      r
    end

    def add_result_subclades(base)
      return nil unless result_files_exist?(base,
        %w[.pdf .classif .medoids .class.tsv .class.nwk])
      r = add_result_iter_clades(base)
      r.add_file(:ani_tree, "miga-project.ani.nwk")
      r
    end

    def add_result_iter_clades(base)
      r = MiGA::Result.new("#{base}.json")
      r.add_file(:report,	"miga-project.pdf")
      r.add_file(:class_table,	"miga-project.class.tsv")
      r.add_file(:class_tree,	"miga-project.class.nwk")
      r.add_file(:classif,	"miga-project.classif")
      r.add_file(:medoids,	"miga-project.medoids")
      r
    end

    def add_result_ogs(base)
      return nil unless result_files_exist?(base, %w[.ogs .stats])
      r = MiGA::Result.new("#{base}.json")
      r.add_file(:ogs, "miga-project.ogs")
      r.add_file(:abc, "miga-project.abc")
      r.add_file(:stats, "miga-project.stats")
      r.add_file(:core_pan, "miga-project.core-pan.tsv")
      r.add_file(:core_pan_plot, "miga-project.core-pan.pdf")
      r
    end

    def add_result_project_stats(base)
      return nil unless
        result_files_exist?(base, %w[.taxonomy.json .metadata.db])
      r = MiGA::Result.new("#{base}.json")
      r.add_file(:taxonomy_index, "miga-project.taxonomy.json")
      r.add_file(:metadata_index, "miga-project.metadata.db")
      r
    end

    alias add_result_haai_distances add_result_distances
    alias add_result_aai_distances add_result_distances
    alias add_result_ani_distances add_result_distances
    alias add_result_ssu_distances add_result_distances

end
