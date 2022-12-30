require 'miga/result'
require 'miga/dataset/base'
require 'miga/common/with_result'

# This library is only required by +#cleanup_distances!+, so it is now
# being loaded on call instead to allow most of miga-base to work without
# issue in systems with problematic SQLite3 installations.
# require 'miga/sqlite'

##
# Helper module including specific functions to add dataset results
module MiGA::Dataset::Result
  include MiGA::Dataset::Base
  include MiGA::Common::WithResult

  ##
  # Return the basename for results
  def result_base
    name
  end

  ##
  # Should I ignore +task+ for this dataset?
  def ignore_task?(task)
    why_ignore(task) != :execute
  end

  ##
  # Return a code explaining why a task is ignored.
  # The values are symbols:
  # - empty: the dataset has no data
  # - inactive: the dataset is inactive
  # - upstream: the task is upstream from dataset's input
  # - force: forced to ignore by metadata
  # - project: incompatible project
  # - noref: incompatible dataset, only for reference
  # - multi: incompatible dataset, only for multi
  # - nonmulti: incompatible dataset, only for nonmulti
  # - complete: the task is already complete
  # - execute: do not ignore, execute the task
  def why_ignore(task)
    if !get_result(task).nil?
      :complete
    elsif !active?
      :inactive
    elsif first_preprocessing.nil?
      :empty
    elsif @@PREPROCESSING_TASKS.index(task) <
          @@PREPROCESSING_TASKS.index(first_preprocessing)
      :upstream
    elsif !metadata["run_#{task}"].nil?
      metadata["run_#{task}"] ? :execute : :force
    elsif task == :taxonomy && project.option(:ref_project).nil?
      :project
    elsif @@_EXCLUDE_NOREF_TASKS_H[task] && !ref?
      :noref
    elsif @@_ONLY_MULTI_TASKS_H[task] && !multi?
      :multi
    elsif @@_ONLY_NONMULTI_TASKS_H[task] && !nonmulti?
      :nonmulti
    else
      :execute
    end
  end

  ##
  # Returns the key symbol of the first registered result (sorted by the
  # execution order). This typically corresponds to the result used as the
  # initial input. Passes +save+ to #add_result.
  def first_preprocessing(save = false)
    @first_processing ||= @@PREPROCESSING_TASKS.find do |t|
      !add_result(t, save).nil?
    end
  end

  ##
  # Returns the key symbol of the next task that needs to be executed or nil.
  # Passes +save+ to #add_result.
  def next_preprocessing(save = false)
    first_preprocessing(save) if save
    next_task(nil, save)
  end

  ##
  # Are all the dataset-specific tasks done? Passes +save+ to #add_result
  def done_preprocessing?(save = false)
    !first_preprocessing(save).nil? && next_preprocessing(save).nil?
  end

  ##
  # Returns an array indicating the stage of each task (sorted by execution
  # order). The values are integers:
  # - 0 for an undefined result (a task before the initial input).
  # - 1 for a registered result (a completed task).
  # - 2 for a queued result (a task yet to be executed).
  # It passes +save+ to #add_result
  def profile_advance(save = false)
    first_task = first_preprocessing(save)
    return Array.new(@@PREPROCESSING_TASKS.size, 0) if first_task.nil?

    adv = []
    state = 0
    next_task = next_preprocessing(save)
    @@PREPROCESSING_TASKS.each do |task|
      state = 1 if first_task == task
      state = 2 if !next_task.nil? && next_task == task
      adv << state
    end
    adv
  end

  ##
  # Returns a Hash with tasks as key and status as value.
  # See +result_status+ for possible values
  def results_status
    Hash[@@PREPROCESSING_TASKS.map { |task| [task, result_status(task)] }]
  end

  ##
  # Returns the status of +task+. The status values are symbols:
  # - -: the task is upstream from the initial input
  # - ignore_*: the task is to be ignored, see codes in #why_ignore
  # - complete: a task with registered results
  # - pending: a task queued to be performed
  def result_status(task)
    reason = why_ignore(task)
    case reason
    when :upstream; :-
    when :execute; :pending
    when :complete; :complete
    else; :"ignore_#{reason}"
    end
  end

  ##
  # Clean-up all the stored distances, removing values for datasets no longer in
  # the project as reference datasets.
  def cleanup_distances!
    r = get_result(:distances)
    return if r.nil?

    require 'miga/sqlite'
    ref = project.datasets.select(&:ref?).select(&:active?).map(&:name)
    %i[haai_db aai_db ani_db].each do |db_type|
      db = r.file_path(db_type)
      next if db.nil? || !File.size?(db)

      sqlite_db = MiGA::SQLite.new(db)
      table = db_type[-6..-4]
      val = sqlite_db.run("select seq2 from #{table}")
      next if val.empty?

      (val.map(&:first) - ref).each do |extra|
        sqlite_db.run("delete from #{table} where seq2=?", extra)
      end
    end
  end

  private

  ##
  # Add result type +:raw_reads+ at +base+ (no +_opts+ supported)
  def add_result_raw_reads(base, _opts)
    return nil unless result_files_exist?(base, '.1.fastq')

    add_files_to_ds_result(
      MiGA::Result.new("#{base}.json"), name,
      if result_files_exist?(base, '.2.fastq')
        { pair1: '.1.fastq', pair2: '.2.fastq' }
      else
        { single: '.1.fastq' }
      end
    )
  end

  ##
  # Add result type +:trimmed_reads+ at +base+ (no +_opts+ supported)
  def add_result_trimmed_reads(base, _opts)
    return nil unless result_files_exist?(base, '.1.clipped.fastq')

    add_files_to_ds_result(
      MiGA::Result.new("#{base}.json"), name,
      if result_files_exist?(base, '.2.clipped.fastq')
        { pair1: '.1.clipped.fastq', pair2: '.2.clipped.fastq' }
      else
        { single: '.1.clipped.fastq' }
      end
    ).tap do |r|
      # Legacy files
      r.add_file(:trimming_sumary, "#{name}.1.fastq.trimmed.summary.txt")
      r.add_file(:single, "#{name}.1.clipped.single.fastq")
    end
  end

  ##
  # Add result type +:read_quality+ at +base+ (no +_opts+ supported)
  def add_result_read_quality(base, _opts)
    return nil unless
      result_files_exist?(base, %w[.post.1.html]) ||
      result_files_exist?(base, %w[.solexaqa .fastqc])

    add_files_to_ds_result(
      MiGA::Result.new("#{base}.json"), name,
      pre_qc_1: '.pre.1.html', pre_qc_2: '.pre.2.html',
      post_qc_1: '.post.1.html', post_qc_2: '.post.2.html',
      adapter_detection: '.adapters.txt',
      # Legacy files
      solexaqa: '.solexaqa', fastqc: '.fastqc'
    )
  end

  ##
  # Add result type +:trimmed_fasta+ at +base+ (no +_opts+ supported)
  def add_result_trimmed_fasta(base, _opts)
    return nil unless
      result_files_exist?(base, '.CoupledReads.fa') ||
      result_files_exist?(base, '.SingleReads.fa')  ||
      result_files_exist?(base, %w[.1.fasta .2.fasta])

    add_files_to_ds_result(
      MiGA::Result.new("#{base}.json"), name,
      coupled: '.CoupledReads.fa',
      single: '.SingleReads.fa',
      pair1: '.1.fasta',
      pair2: '.2.fasta'
    )
  end

  ##
  # Add result type +:assembly+ at +base+. Hash +opts+ supports
  # +is_clean: Boolean+.
  def add_result_assembly(base, opts)
    return nil unless result_files_exist?(base, '.LargeContigs.fna')

    r = add_files_to_ds_result(
      MiGA::Result.new("#{base}.json"), name,
      largecontigs: '.LargeContigs.fna',
      allcontigs: '.AllContigs.fna',
      assembly_data: ''
    )
    opts[:is_clean] ||= false
    r.clean! if opts[:is_clean]
    unless r.clean?
      MiGA::MiGA.clean_fasta_file(r.file_path(:largecontigs))
      r.clean!
    end
    r
  end

  ##
  # Add result type +:cds+ at +base+. Hash +opts+ supports +is_clean: Boolean+
  def add_result_cds(base, opts)
    return nil unless result_files_exist?(base, %w[.faa])

    r = add_files_to_ds_result(
      MiGA::Result.new("#{base}.json"), name,
      proteins: '.faa',
      genes: '.fna',
      gff2: '.gff2',
      gff3: '.gff3',
      tab: '.tab'
    )
    opts[:is_clean] ||= false
    r.clean! if opts[:is_clean]
    unless r.clean?
      MiGA::MiGA.clean_fasta_file(r.file_path(:proteins))
      MiGA::MiGA.clean_fasta_file(r.file_path(:genes)) if r.file_path(:genes)
      r.clean!
    end
    r
  end

  ##
  # Add result type +:essential_genes+ at +base+ (no +_opts+ supported).
  def add_result_essential_genes(base, _opts)
    return nil unless result_files_exist?(base, %w[.ess.faa .ess .ess/log])

    add_files_to_ds_result(
      MiGA::Result.new("#{base}.json"), name,
      ess_genes: '.ess.faa',
      collection: '.ess',
      report: '.ess/log',
      alignments: '.ess/proteins.aln',
      fastaai_index: '.faix.db.gz',
      fastaai_index_2: '.faix'
    )
  end

  ##
  # Add result type +:ssu+ at +base+. Hash +opts+ supports +is_clean: Boolean+
  def add_result_ssu(base, opts)
    return MiGA::Result.new("#{base}.json") if result(:assembly).nil?
    return nil unless result_files_exist?(base, '.ssu.fa')

    r = add_files_to_ds_result(
      MiGA::Result.new("#{base}.json"), name,
      longest_ssu_gene: '.ssu.fa',
      ssu_gff: '.ssu.gff', # DEPRECATED
      gff: '.gff',
      all_ssu_genes: '.ssu.all.fa',
      classification: '.rdp.tsv',
      trna_list: '.trna.txt'
    )
    opts[:is_clean] ||= false
    r.clean! if opts[:is_clean]
    unless r.clean?
      MiGA::MiGA.clean_fasta_file(r.file_path(:longest_ssu_gene))
      r.clean!
    end
    r
  end

  ##
  # Add result type +:mytaxa+ at +base+ (no +_opts+ supported)
  def add_result_mytaxa(base, _opts)
    if multi?
      return nil unless
        result_files_exist?(base, '.mytaxa') ||
        result_files_exist?(base, '.nomytaxa.txt')

      add_files_to_ds_result(
        MiGA::Result.new("#{base}.json"), name,
        mytaxa: '.mytaxa',
        blast: '.blast',
        mytaxain: '.mytaxain',
        nomytaxa: '.nomytaxa.txt',
        species: '.mytaxa.Species.txt',
        genus: '.mytaxa.Genus.txt',
        phylum: '.mytaxa.Phylum.txt',
        innominate: '.mytaxa.innominate',
        kronain: '.mytaxa.krona',
        krona: '.html'
      )
    else
      MiGA::Result.new("#{base}.json")
    end
  end

  ##
  # Add result type +:mytaxa_scan+ at +base+ (no +_opts+ supported)
  def add_result_mytaxa_scan(base, _opts)
    if nonmulti?
      return nil unless
        result_files_exist?(base, %w[.pdf .mytaxa]) ||
        result_files_exist?(base, '.nomytaxa.txt')

      add_files_to_ds_result(
        MiGA::Result.new("#{base}.json"), name,
        nomytaxa: '.nomytaxa.txt',
        mytaxa: '.mytaxa',
        report: '.pdf',
        regions_archive: '.reg.tar',
        # Intermediate / Deprecated:
        blast: '.blast',
        mytaxain: '.mytaxain',
        wintax: '.wintax',
        gene_ids: '.wintax.genes',
        region_ids: '.wintax.regions',
        regions: '.reg'
      )
    else
      MiGA::Result.new("#{base}.json")
    end
  end

  ##
  # Add result type +:distances+ at +base+ (no +_opts+ supported)
  def add_result_distances(base, _opts)
    if nonmulti?
      if ref?
        add_result_distances_ref(base)
      else
        add_result_distances_nonref(base)
      end
    else
      add_result_distances_multi(base)
    end
  end

  ##
  # Add result type +:taxonomy+ at +base+ (no +_opts+ supported)
  def add_result_taxonomy(base, _opts)
    add_result_distances_nonref(base)
  end

  ##
  # Add result type +:stats+ at +base+ (no +_opts+ supported)
  def add_result_stats(base, _opts)
    MiGA::Result.new("#{base}.json")
  end

  ##
  # Add result type +:distances+ for _multi_ datasets at +base+
  def add_result_distances_multi(base)
    MiGA::Result.new("#{base}.json")
  end

  ##
  # Add result type +:distances+ for _nonmulti_ reference datasets at +base+
  def add_result_distances_ref(base)
    pref = File.dirname(base)
    return nil unless File.exist?("#{pref}/01.haai/#{name}.db")

    MiGA::Result.new("#{base}.json").tap do |r|
      r.add_files(
        haai_db: "01.haai/#{name}.db",
        aai_db: "02.aai/#{name}.db",
        ani_db: "03.ani/#{name}.db"
      )
    end
  end

  ##
  # Add result type +:distances+ for _nonmulti_ query datasets at +base+
  def add_result_distances_nonref(base)
    return nil unless
      result_files_exist?(base, %w[.aai-medoids.tsv .aai.db]) ||
      result_files_exist?(base, %w[.ani-medoids.tsv .ani.db])

    add_files_to_ds_result(
      MiGA::Result.new("#{base}.json"), name,
      aai_medoids: '.aai-medoids.tsv',
      haai_db: '.haai.db',
      aai_db: '.aai.db',
      ani_medoids: '.ani-medoids.tsv',
      ani_db: '.ani.db',
      ref_tree: '.nwk',
      ref_tree_pdf: '.nwk.pdf',
      intax_test: '.intax.txt'
    )
  end

  ##
  # Add files in +rel_files+ Hash to the result +r+ with dataset name +name+
  def add_files_to_ds_result(r, name, rel_files)
    files = {}
    rel_files.each { |k, v| files[k] = name + v }
    r.add_files(files)
    r
  end
end
