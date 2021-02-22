# frozen_string_literal: true

require 'miga/common/with_option'

class MiGA::Project < MiGA::MiGA
  include MiGA::Common::WithOption

  class << self
    ##
    # Does the project at +path+ exist?
    def exist?(path)
      Dir.exist?(path) and File.exist?("#{path}/miga.project.json")
    end

    ##
    # Load the project at +path+. Returns MiGA::Project if project exists, nil
    # otherwise.
    def load(path)
      return nil unless exist? path

      new path
    end

    def INCLADE_TASKS
      @@INCLADE_TASKS
    end

    def DISTANCE_TASKS
      @@DISTANCE_TASKS
    end

    def KNOWN_TYPES
      @@KNOWN_TYPES
    end

    def RESULT_DIRS
      @@RESULT_DIRS
    end

    def OPTIONS
      @@OPTIONS
    end
  end
end

module MiGA::Project::Base
  ##
  # Top-level folders inside a project
  @@FOLDERS = %w[data metadata daemon]

  ##
  # Folders for results
  @@DATA_FOLDERS = %w[
    01.raw_reads 02.trimmed_reads 03.read_quality 04.trimmed_fasta
    05.assembly 06.cds
    07.annotation 07.annotation/01.function 07.annotation/02.taxonomy
    07.annotation/01.function/01.essential
    07.annotation/01.function/02.ssu
    07.annotation/02.taxonomy/01.mytaxa
    07.annotation/03.qa 07.annotation/03.qa/02.mytaxa_scan
    08.mapping 08.mapping/01.read-ctg 08.mapping/02.read-gene
    09.distances 09.distances/01.haai 09.distances/02.aai
    09.distances/03.ani 09.distances/04.ssu 09.distances/05.taxonomy
    10.clades 10.clades/01.find 10.clades/02.ani 10.clades/03.ogs
    90.stats
  ]

  ##
  # Directories containing the results from project-wide tasks
  @@RESULT_DIRS = {
    project_stats: '90.stats',
    # Distances
    haai_distances: '09.distances/01.haai',
    aai_distances: '09.distances/02.aai',
    ani_distances: '09.distances/03.ani',
    # ssu_distances: '09.distances/04.ssu',
    # Clade identification
    clade_finding: '10.clades/01.find',
    # Clade analysis
    subclades: '10.clades/02.ani',
    ogs: '10.clades/03.ogs'
    # ess_phylogeny: '10.clades/04.phylogeny/01.essential',
    # core_phylogeny: '10.clades/04.phylogeny/02.core',
    # clade_metadata: '10.clades/05.metadata'
  }

  ##
  # Supported types of projects
  @@KNOWN_TYPES = {
    mixed: {
      description: 'Mixed collection of genomes, metagenomes, and viromes',
      single: true, multi: true
    },
    genomes: {
      description: 'Collection of genomes',
      single: true, multi: false
    },
    clade: {
      description: 'Collection of closely-related genomes (ANI >= 90%)',
      single: true, multi: false
    },
    metagenomes: {
      description: 'Collection of metagenomes and/or viromes',
      single: false, multi: true
    }
  }

  ##
  # Project-wide distance estimations
  @@DISTANCE_TASKS = [
    :project_stats, :haai_distances, :aai_distances, :ani_distances,
    :clade_finding
  ]

  ##
  # Project-wide tasks for :clade projects
  @@INCLADE_TASKS = [:subclades, :ogs]

  ##
  # Options supported by projects
  @@OPTIONS = {
    ref_project: {
      desc: 'Project with reference taxonomy', type: String
    },
    db_proj_dir: {
      desc: 'Directory containing database projects', type: String
    },
    tax_pvalue: {
      desc: 'Maximum p-value to transfer taxonomy', default: 0.05, type: Float,
      in: 0.0..1.0
    },
    haai_p: {
      desc: 'Value of aai.rb -p on hAAI', type: String,
      default: proc { |project| project.clade? ? 'no' : 'blast+' },
      in: %w[fastaai blast+ blast blat diamond no]
    },
    aai_p: {
      desc: 'Value of aai.rb -p on AAI', default: 'blast+', type: String,
      in: %w[blast+ blast blat diamond]
    },
    ani_p: {
      desc: 'Value of ani.rb -p on ANI', default: 'blast+', type: String,
      in: %w[blast+ blast blat fastani]
    },
    max_try: {
      desc: 'Maximum number of task attempts', default: 10, type: Integer,
      in: (0..1000)
    },
    aai_save_rbm: {
      desc: 'Should RBMs be saved for OGS analysis?',
      default: proc { |project| project.clade? },
      in: [true, false]
    },
    ogs_identity: {
      desc: 'Min RBM identity for OGS', default: 80.0, type: Float,
      in: (0.0..100.0)
    },
    clean_ogs: {
      desc: 'If false, keeps ABC files (clades only)', default: true,
      in: [true, false]
    },
    run_clades: {
      desc: 'Should clades be estimated from distances?', default: true,
      in: [true, false]
    },
    gsp_ani: {
      desc: 'ANI limit to propose gsp clades', default: 95.0, type: Float,
      in: (0.0..100.0)
    },
    gsp_aai: {
      desc: 'AAI limit to propose gsp clades', default: 90.0, type: Float,
      in: (0.0..100.0)
    },
    gsp_metric: {
      desc: 'Metric to propose clades', default: 'ani', type: String,
      in: %w[ani aai]
    },
    ess_coll: {
      desc: 'Collection of essential genes to use', default: 'dupont_2012',
      type: String, in: %w[dupont_2012 lee_2019]
    },
    min_qual: {
      desc: 'Minimum genome quality', default: 25.0, type: Float,
      in: -Float::INFINITY..100.0, tokens: %w[no]
    },
    distances_checkpoint: {
      desc: 'Number of comparisons before storing data', default: 10,
      type: Integer, in: 1...Float::INFINITY
    }
  }
end
