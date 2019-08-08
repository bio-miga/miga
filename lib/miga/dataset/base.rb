# @package MiGA
# @license Artistic-2.0

class MiGA::Dataset < MiGA::MiGA

  # Class-level
  class << self
    def RESULT_DIRS ; @@RESULT_DIRS ; end
    def KNOWN_TYPES ; @@KNOWN_TYPES ; end
    def PREPROCESSING_TASKS ; @@PREPROCESSING_TASKS ; end
  end
  
end

module MiGA::Dataset::Base
  
  ##
  # Directories containing the results from dataset-specific tasks.
  @@RESULT_DIRS = {
    # Preprocessing
    raw_reads: "01.raw_reads", trimmed_reads: "02.trimmed_reads",
    read_quality: "03.read_quality", trimmed_fasta: "04.trimmed_fasta",
    assembly: "05.assembly", cds: "06.cds",
    # Annotation
    essential_genes: "07.annotation/01.function/01.essential",
    ssu: "07.annotation/01.function/02.ssu",
    mytaxa: "07.annotation/02.taxonomy/01.mytaxa",
    mytaxa_scan: "07.annotation/03.qa/02.mytaxa_scan",
    # Distances (for single-species datasets)
    distances: "09.distances", taxonomy: "09.distances/05.taxonomy",
    # General statistics
    stats: "90.stats"
  }

  ##
  # Supported dataset types.
  @@KNOWN_TYPES = {
    genome: {description: 'The genome from an isolate.', multi: false},
    scgenome: {description: 'A Single-cell Amplidied Genome (SAG).',
      multi: false},
    popgenome: {description: 'A Metagenome-Assembled Genome (MAG).',
      :multi=>false},
    metagenome: {description: 'A metagenome (excluding viromes).',
      multi: true},
    virome: {description: 'A viral metagenome.', multi: true}
  }

  ##
  # Returns an Array of tasks to be executed before project-wide tasks.
  @@PREPROCESSING_TASKS = [:raw_reads, :trimmed_reads, :read_quality,
    :trimmed_fasta, :assembly, :cds, :essential_genes, :ssu, :mytaxa,
    :mytaxa_scan, :distances, :taxonomy, :stats]
  
  ##
  # Tasks to be excluded from query datasets.
  @@EXCLUDE_NOREF_TASKS = [:mytaxa_scan, :taxonomy]
  @@_EXCLUDE_NOREF_TASKS_H = Hash[@@EXCLUDE_NOREF_TASKS.map{ |i| [i,true] }]
  
  ##
  # Tasks to be executed only in datasets that are not multi-organism. These
  # tasks are ignored for multi-organism datasets or for unknown types.
  @@ONLY_NONMULTI_TASKS = [:mytaxa_scan, :distances, :taxonomy]
  @@_ONLY_NONMULTI_TASKS_H = Hash[@@ONLY_NONMULTI_TASKS.map{ |i| [i,true] }]

  ##
  # Tasks to be executed only in datasets that are multi-organism. These
  # tasks are ignored for single-organism datasets or for unknwon types.
  @@ONLY_MULTI_TASKS = [:mytaxa]
  @@_ONLY_MULTI_TASKS_H = Hash[@@ONLY_MULTI_TASKS.map{ |i| [i,true] }]


end

