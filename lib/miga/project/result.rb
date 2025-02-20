# @package MiGA
# @license Artistic-2.0

require 'miga/result'
require 'miga/project/base'
require 'miga/common/with_result'

##
# Helper module including specific functions to add project results.
module MiGA::Project::Result
  include MiGA::Project::Base
  include MiGA::Common::WithResult

  ##
  # Return the basename for results
  def result_base
    'miga-project'
  end

  ##
  # Return itself, to simplify modules
  def project
    self
  end

  ##
  # Do nothing, only to comply with MiGA::Common::WithResult
  def inactivate!(reason = nil)
  end

  ##
  # Is this +task+ to be bypassed?
  def ignore_task?(task)
    opt = "run_#{task}"
    return true if metadata[opt] == false
    return true if option?(opt) && option(opt) == false

    !clade? && @@INCLADE_TASKS.include?(task) && metadata[opt] != true
  end

  ##
  # Get the next distances task, saving intermediate results if +save+. Returns
  # a Symbol.
  def next_distances(save = true)
    next_task(@@DISTANCE_TASKS, save)
  end

  ##
  # Get the next inclade task, saving intermediate results if +save+. Returns a
  # Symbol.
  def next_inclade(save = true)
    next_task(@@INCLADE_TASKS, save)
  end

  private

  ##
  # Add result of any type +:*_distances+ at +base+ (no +_opts+ supported).
  def add_result_distances(base, _opts)
    return nil unless result_files_exist?(base, ['.txt']) &&
      (result_files_exist?(base, ['.rds']) ||
       result_files_exist?(base, ['.rda']))

    r = MiGA::Result.new("#{base}.json")
    r.add_file(:rds,    'miga-project.rds')
    r.add_file(:rda,    'miga-project.rda')
    r.add_file(:rdata,  'miga-project.Rdata') # Legacy file
    r.add_file(:matrix, 'miga-project.txt')
    r.add_file(:log,    'miga-project.log') # Legacy file
    r.add_file(:hist,   'miga-project.hist')
    r
  end

  ##
  # Add result type +:clade_finding+ at +base+ (no +_opts+ supported).
  def add_result_clade_finding(base, _opts)
    r = nil
    if result_files_exist?(base, %w[.empty])
      r = MiGA::Result.new("#{base}.json")
      r.add_file(:empty, 'miga-project.empty')
    else
      return nil unless result_files_exist?(base, %w[.proposed-clades])
      unless clade? ||
             result_files_exist?(
               base, %w[.pdf .classif .medoids .class.tsv .class.nwk]
             )
        return nil
      end
      r = add_result_iter_clades(base)
    end

    r.add_file(:aai_dist_rds, 'miga-project.dist.rds')
    r.add_file(:aai_dist_rda, 'miga-project.dist.rda')
    r.add_file(:aai_tree,     'miga-project.aai.nwk')
    r.add_file(:proposal,     'miga-project.proposed-clades')
    r.add_file(:clades_aai90, 'miga-project.aai90-clades')
    r.add_file(:clades_ani95, 'miga-project.ani95-clades')
    r.add_file(:clades_gsp,   'miga-project.gsp-clades')
    r.add_file(:medoids_gsp,  'miga-project.gsp-medoids')
    r
  end

  ##
  # Add result type +:subclades+ at +base+ (no +_opts+ supported).
  def add_result_subclades(base, _opts)
    if result_files_exist?(base, %w[.empty])
      r = MiGA::Result.new("#{base}.json")
      r.add_file(:empty, 'miga-project.empty')
      return r
    end
    return nil unless result_files_exist?(
      base, %w[.pdf .classif .medoids .class.tsv .class.nwk]
    )

    r = add_result_iter_clades(base)
    r.add_file(:ani_tree, 'miga-project.ani.nwk')
    r.add_file(:ani_dist_rds, 'miga-project.dist.rds')
    r.add_file(:ani_dist_rda, 'miga-project.dist.rda')
    r
  end

  ##
  # Helper function for clade iterations.
  def add_result_iter_clades(base)
    r = MiGA::Result.new("#{base}.json")
    r.add_file(:report,      'miga-project.pdf')
    r.add_file(:class_table, 'miga-project.class.tsv')
    r.add_file(:class_tree,  'miga-project.class.nwk')
    r.add_file(:classif,     'miga-project.classif')
    r.add_file(:medoids,     'miga-project.medoids')
    r
  end

  ##
  # Add result type +:ogs+ at +base+ (no +_opts+ supported).
  def add_result_ogs(base, _opts)
    if result_files_exist?(base, %w[.empty])
      r = MiGA::Result.new("#{base}.json")
      r.add_file(:empty, 'miga-project.empty')
      return r
    end
    return nil unless result_files_exist?(base, %w[.ogs .stats])

    r = MiGA::Result.new("#{base}.json")
    r.add_file(:ogs,   'miga-project.ogs')
    r.add_file(:abc,   'miga-project.abc')
    r.add_file(:stats, 'miga-project.stats')
    r.add_file(:core_pan,      'miga-project.core-pan.tsv')
    r.add_file(:core_pan_plot, 'miga-project.core-pan.pdf')
    r
  end

  ##
  # Add result type +:project_stats+ at +base+ (no +_opts+ supported).
  def add_result_project_stats(base, _opts)
    return nil unless
      result_files_exist?(base, %w[.taxonomy.json .metadata.db])

    r = MiGA::Result.new("#{base}.json")
    r.add_file(:taxonomy_index, 'miga-project.taxonomy.json')
    r.add_file(:metadata_index, 'miga-project.metadata.db')
    r
  end

  alias add_result_haai_distances add_result_distances
  alias add_result_aai_distances add_result_distances
  alias add_result_ani_distances add_result_distances
  alias add_result_ssu_distances add_result_distances
end
