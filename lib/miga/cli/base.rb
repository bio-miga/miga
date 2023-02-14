# frozen_string_literal: true

module MiGA::Cli::Base
  @@TASK_DESC = {
    generic: 'MiGA: The Microbial Genomes Atlas',
    # Workflows
    quality_wf: 'Evaluate the quality of input genomes',
    derep_wf: 'Dereplicate a collection of input genomes',
    classify_wf: 'Classify input genomes against a reference database',
    preproc_wf: 'Preprocess input genomes or metagenomes',
    index_wf: 'Generate distance indexing of input genomes',
    # Projects
    new: 'Create an empty MiGA project',
    about: 'Display information about a MiGA project',
    doctor: 'Perform consistency checks on a MiGA project',
    get_db: 'Download a pre-indexed database',
    browse: 'Explore a project locally using a web browser',
    # Datasets
    add: 'Create a dataset in a MiGA project',
    get: 'Download a dataset from public databases into a MiGA project',
    ncbi_get: 'Download all genomes in a taxon from NCBI into a MiGA project',
    gtdb_get: 'Download all genomes in a taxon from GTDB into a MiGA project',
    seqcode_get: 'Download all type genomes from SeqCode into a MiGA project',
    rm: 'Remove a dataset from a MiGA project',
    find: 'Find unregistered datasets based on result files',
    ln: 'Link datasets (including results) from one project to another',
    ls: 'List all registered datasets in a MiGA project',
    archive: 'Generate a tar-ball with all files from select datasets',
    # Results
    add_result: 'Register a result',
    stats: 'Extract statistics for the given result',
    files: 'List registered files from the results of a dataset or project',
    run: 'Execute locally one step analysis producing the given result',
    summary: 'Generate a summary table for the statistics of all datasets',
    next_step: 'Return the next task to run in a dataset or project',
    # Objects (Datasets or Projects)
    edit: 'Edit the metadata of a dataset or project',
    option: 'Get or set options of a dataset or project',
    touch: 'Change the "last modified" time to now without changes',
    # System
    init: 'Initialize MiGA to process new projects',
    daemon: 'Control the daemon of a MiGA project',
    lair: 'Control groups of daemons for several MiGA projects',
    date: 'Return the current date in standard MiGA format',
    console: 'Open an IRB console with MiGA',
    env: 'Shell code to load MiGA environment',
    # Taxonomy
    tax_set: 'Register taxonomic information for datasets',
    tax_test: 'Return test of taxonomic distributions for query datasets',
    tax_index: 'Create a taxonomy-indexed list of the datasets',
    tax_dist: 'Estimate distributions of distance by taxonomy',
  }

  @@TASK_ALIAS = {
    # Projects
    create_project: :new,
    project_info: :about,
    download: :get_db,
    # Datasets
    create_dataset: :add,
    download_dataset: :get,
    unlink_dataset: :rm,
    find_datasets: :find,
    import_datasets: :ln,
    list_datasets: :ls,
    # Results
    result_stats: :stats,
    list_files: :files,
    run_local: :run,
    sum_stats: :summary,
    next_task: :next_step,
    # Objects
    update_metadata: :edit,
    # System
    c: :console,
    # Taxonomy
    add_taxonomy: :tax_set,
    test_taxonomy: :tax_test,
    index_taxonomy: :tax_index,
    tax_distributions: :tax_dist,
  }

  @@TASK_ALIAS.each do |nick, task|
    @@TASK_DESC[task] = (
      (@@TASK_DESC[task] =~ /\(alias: .*\)\./) ?
        @@TASK_DESC[task].sub(/\)\.$/, ", #{nick}).") :
        @@TASK_DESC[task].sub(/\.$/, " (alias: #{nick}).")
    )
  end

  @@EXECS = @@TASK_DESC.keys

  @@FILE_REGEXP =
    %r{^(?:.*/)?(.+?)(\.[A-Z]*(Reads|Contigs))?(\.f[nastq]+)?(\.gz)?$}i

  @@PAIRED_FILE_REGEXP =
    %r{^(?:.*/)?(.+?)(\.[A-Z]*([12]|Reads))?(\.f[nastq]+)?(\.gz)?$}i
end

class MiGA::Cli < MiGA::MiGA
  include MiGA::Cli::Base

  class << self
    def TASK_DESC
      @@TASK_DESC
    end

    def TASK_ALIAS
      @@TASK_ALIAS
    end

    def EXECS
      @@EXECS
    end

    def FILE_REGEXP(paired = false)
      paired ? @@PAIRED_FILE_REGEXP : @@FILE_REGEXP
    end
  end
end
