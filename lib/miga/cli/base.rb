# @package MiGA
# @license Artistic-2.0

module MiGA::Cli::Base

  @@TASK_DESC = {
    generic:  'MiGA: The Microbial Genomes Atlas',
    # Workflows
    quality_wf:  'Evaluate the quality of input genomes',
    derep_wf:    'Dereplicate a collection of input genomes',
    classify_wf: 'Classify input genomes against a reference database',
    preproc_wf:  'Preprocess input genomes or metagenomes',
    index_wf:    'Generate distance indexing of input genomes',
    # Projects
    new:      'Creates an empty MiGA project',
    about:    'Displays information about a MiGA project',
    plugins:  'Lists or (un)installs plugins in a MiGA project',
    doctor:   'Performs consistency checks on a MiGA project',
    get_db:   'Downloads a pre-indexed database',
    # Datasets
    add:      'Creates a dataset in a MiGA project',
    get:      'Downloads a dataset from public databases into a MiGA project',
    ncbi_get: 'Downloads all genomes in a taxon from NCBI into a MiGA project',
    rm:       'Removes a dataset from an MiGA project',
    find:     'Finds unregistered datasets based on result files',
    ln:       'Link datasets (including results) from one project to another',
    ls:       'Lists all registered datasets in an MiGA project',
    # Results
    add_result: 'Registers a result',
    stats:    'Extracts statistics for the given result',
    files:    'Lists registered files from the results of a dataset or project',
    run:      'Executes locally one step analysis producing the given result',
    summary:  'Generates a summary table for the statistics of all datasets',
    next_step: 'Returns the next task to run in a dataset or project',
    # Objects (Datasets or Projects)
    edit:     'Edits the metadata of a dataset or project',
    # System
    init:     'Initialize MiGA to process new projects',
    daemon:   'Controls the daemon of a MiGA project',
    date:     'Returns the current date in standard MiGA format',
    console:  'Opens an IRB console with MiGA',
    # Taxonomy
    tax_set:  'Registers taxonomic information for datasets',
    tax_test: 'Returns test of taxonomic distributions for query datasets',
    tax_index: 'Creates a taxonomy-indexed list of the datasets',
    tax_dist: 'Estimates distributions of distance by taxonomy',
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
    @@TASK_DESC[task] = ((@@TASK_DESC[task] =~ /\(alias: .*\)\./) ?
        @@TASK_DESC[task].sub(/\)\.$/, ", #{nick}).") :
        @@TASK_DESC[task].sub(/\.$/, " (alias: #{nick}).")
    )
  end

  @@EXECS = @@TASK_DESC.keys

  @@FILE_REGEXP = %r{^(?:.*/)?(.+?)(?:\..*(?:[12]|Reads|Contigs))?(?:\.f[nastq]+)?$}i

end

class MiGA::Cli < MiGA::MiGA

  include MiGA::Cli::Base

  class << self
    def TASK_DESC; @@TASK_DESC end
    def TASK_ALIAS; @@TASK_ALIAS end
    def EXECS; @@EXECS end
    def FILE_REGEXP; @@FILE_REGEXP end
  end
end
