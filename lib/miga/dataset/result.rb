
require "sqlite3"
require "miga/result"
require "miga/dataset/base"

##
# Helper module including specific functions to add dataset results.
module MiGA::Dataset::Result
  
  include MiGA::Dataset::Base
  
  ##
  # Get the result MiGA::Result in this dataset identified by the symbol +k+.
  def result(k)
    return nil if @@RESULT_DIRS[k.to_sym].nil?
    MiGA::Result.load(
      "#{project.path}/data/#{@@RESULT_DIRS[k.to_sym]}/#{name}.json" )
  end
  
  ##
  # Get all the results (Array of MiGA::Result) in this dataset.
  def results ; @@RESULT_DIRS.keys.map{ |k| result k }.compact ; end
  
  ##
  # For each result executes the 2-ary +blk+ block: key symbol and MiGA::Result.
  def each_result(&blk)
    @@RESULT_DIRS.keys.each do |k|
      blk.call(k, result(k)) unless result(k).nil?
    end
  end
  
  ##
  # Look for the result with symbol key +result_type+ and register it in the
  # dataset. If +save+ is false, it doesn't register the result, but it still
  # returns a result if the expected files are complete. The +opts+ hash
  # controls result creation (if necessary). Supported values include:
  # - +is_clean+: A Boolean indicating if the input files are clean.
  # - +force+: A Boolean indicating if the result must be re-indexed. If true, it
  #   implies save=true.
  # Returns MiGA::Result or nil.
  def add_result(result_type, save=true, opts={})
    dir = @@RESULT_DIRS[result_type]
    return nil if dir.nil?
    base = File.expand_path("data/#{dir}/#{name}", project.path)
    if opts[:force]
      FileUtils.rm("#{base}.json") if File.exist?("#{base}.json")
    else
      r_pre = MiGA::Result.load("#{base}.json")
      return r_pre if (r_pre.nil? and not save) or not r_pre.nil?
    end
    r = File.exist?("#{base}.done") ?
        self.send("add_result_#{result_type}", base, opts) : nil
    r.save unless r.nil?
    r
  end

  ##
  # Gets a result as MiGA::Result for the datasets with +result_type+. This is
  # equivalent to +add_result(result_type, false)+.
  def get_result(result_type) ; add_result(result_type, false) ; end

  ##
  # Returns the key symbol of the first registered result (sorted by the
  # execution order). This typically corresponds to the result used as the
  # initial input. Passes +save+ to #add_result.
  def first_preprocessing(save=false)
    @@PREPROCESSING_TASKS.find do |t|
      not ignore_task?(t) and not add_result(t, save).nil?
    end
  end
  
  ##
  # Returns the key symbol of the next task that needs to be executed. Passes
  # +save+ to #add_result.
  def next_preprocessing(save=false)
    after_first = false
    first = first_preprocessing(save)
    return nil if first.nil?
    @@PREPROCESSING_TASKS.each do |t|
      next if ignore_task? t
      return t if after_first and add_result(t, save).nil?
      after_first = (after_first or (t==first))
    end
    nil
  end

  ##
  # Are all the dataset-specific tasks done? Passes +save+ to #add_result.
  def done_preprocessing?(save=false)
    !first_preprocessing(save).nil? and next_preprocessing(save).nil?
  end
  
  ##
  # Returns an array indicating the stage of each task (sorted by execution
  # order). The values are integers:
  # - 0 for an undefined result (a task before the initial input).
  # - 1 for a registered result (a completed task).
  # - 2 for a queued result (a task yet to be executed).
  # It passes +save+ to #add_result
  def profile_advance(save=false)
    first_task = first_preprocessing(save)
    return Array.new(@@PREPROCESSING_TASKS.size, 0) if first_task.nil?
    adv = []
    state = 0
    next_task = next_preprocessing(save)
    @@PREPROCESSING_TASKS.each do |task|
      state = 1 if first_task==task
      state = 2 if !next_task.nil? and next_task==task
      adv << state
    end
    adv
  end
  
  ##
  # Clean-up all the stored distances, removing values for datasets no longer in
  # the project as reference datasets.
  def cleanup_distances!
    r = get_result(:distances)
    return if r.nil?
    [:haai_db, :aai_db, :ani_db].each do |db_type|
      db = r.file_path(db_type)
      next if db.nil? or not File.size? db
      sqlite_db = SQLite3::Database.new db
      table = db_type[-6..-4]
      val = sqlite_db.execute "select seq2 from #{table}"
      next if val.empty?
      (val.map{ |i| i.first } - project.dataset_names).each do |extra|
        sqlite_db.execute "delete from #{table} where seq2=?", extra
      end
    end
  end

  private

    ##
    # Add result type +:raw_reads+ at +base+ (no +_opts+ supported).
    def add_result_raw_reads(base, _opts)
      return nil unless result_files_exist?(base, ".1.fastq")
      r = MiGA::Result.new("#{base}.json")
      add_files_to_ds_result(r, name,
        ( result_files_exist?(base, ".2.fastq") ?
          {pair1:".1.fastq", pair2:".2.fastq"} :
          {single:".1.fastq"} ))
    end

    ##
    # Add result type +:trimmed_reads+ at +base+ (no +_opts+ supported).
    def add_result_trimmed_reads(base, _opts)
      return nil unless result_files_exist?(base, ".1.clipped.fastq")
      r = MiGA::Result.new("#{base}.json")
      if result_files_exist?(base, ".2.clipped.fastq")
        r = add_files_to_ds_result(r, name,
          pair1:".1.clipped.fastq", pair2:".2.clipped.fastq",
          single:".1.clipped.single.fastq")
      else
        r = add_files_to_ds_result(r, name, single:".1.clipped.fastq")
      end
      r.add_file(:trimming_sumary, "#{name}.1.fastq.trimmed.summary.txt")
      add_result(:raw_reads) #-> Post gunzip
      r
    end

    ##
    # Add result type +:read_quality+ at +base+ (no +_opts+ supported).
    def add_result_read_quality(base, _opts)
      return nil unless result_files_exist?(base, %w[.solexaqa .fastqc])
      r = MiGA::Result.new("#{base}.json")
      r = add_files_to_ds_result(r, name,
        solexaqa:".solexaqa", fastqc:".fastqc")
      add_result(:trimmed_reads) #-> Post cleaning
      r
    end

    ##
    # Add result type +:trimmed_fasta+ at +base+ (no +_opts+ supported).
    def add_result_trimmed_fasta(base, _opts)
      return nil unless
        result_files_exist?(base, ".CoupledReads.fa") or
        result_files_exist?(base, ".SingleReads.fa") or
        result_files_exist?(base, %w[.1.fasta .2.fasta])
      r = MiGA::Result.new("#{base}.json")
      r = add_files_to_ds_result(r, name, coupled:".CoupledReads.fa",
        single:".SingleReads.fa", pair1:".1.fasta", pair2:".2.fasta")
      add_result(:raw_reads) #-> Post gzip
      r
    end

    ##
    # Add result type +:assembly+ at +base+. Hash +opts+ supports
    # +is_clean: Boolean+.
    def add_result_assembly(base, opts)
      return nil unless result_files_exist?(base, ".LargeContigs.fna")
      r = MiGA::Result.new("#{base}.json")
      r = add_files_to_ds_result(r, name, largecontigs:".LargeContigs.fna",
        allcontigs:".AllContigs.fna", assembly_data:"")
      opts[:is_clean] ||= false
      r.clean! if opts[:is_clean]
      unless r.clean?
        MiGA::MiGA.clean_fasta_file(r.file_path :largecontigs)
        r.clean!
      end
      add_result(:trimmed_fasta) #-> Post interposing
      r
    end

    ##
    # Add result type +:cds+ at +base+. Hash +opts+ supports +is_clean: Boolean+
    def add_result_cds(base, opts)
      return nil unless result_files_exist?(base, %w[.faa .fna])
      r = MiGA::Result.new("#{base}.json")
      r = add_files_to_ds_result(r, name, proteins:".faa", genes:".fna",
        gff2:".gff2", gff3:".gff3", tab:".tab")
      opts[:is_clean] ||= false
      r.clean! if opts[:is_clean]
      unless r.clean?
        MiGA::MiGA.clean_fasta_file(r.file_path :proteins)
        MiGA::MiGA.clean_fasta_file(r.file_path :genes)
        r.clean!
      end
      r
    end

    ##
    # Add result type +:essential_genes+ at +base+ (no +_opts+ supported).
    def add_result_essential_genes(base, _opts)
      return nil unless result_files_exist?(base, %w[.ess.faa .ess .ess/log])
      r = MiGA::Result.new("#{base}.json")
      add_files_to_ds_result(r, name, ess_genes:".ess.faa",
        collection:".ess", report:".ess/log")
    end

    ##
    # Add result type +:ssu+ at +base+. Hash +opts+ supports +is_clean: Boolean+
    def add_result_ssu(base, opts)
      return MiGA::Result.new("#{base}.json") if result(:assembly).nil?
      return nil unless result_files_exist?(base, ".ssu.fa")
      r = MiGA::Result.new("#{base}.json")
      r = add_files_to_ds_result(r, name, longest_ssu_gene:".ssu.fa",
        gff:".ssu.gff", all_ssu_genes:".ssu.all.fa")
      opts[:is_clean] ||= false
      r.clean! if opts[:is_clean]
      unless r.clean?
        MiGA::MiGA.clean_fasta_file(r.file_path :longest_ssu_gene)
        r.clean!
      end
      r
    end

    ##
    # Add result type +:mytaxa+ at +base+ (no +_opts+ supported).
    def add_result_mytaxa(base, _opts)
      if is_multi?
        return nil unless result_files_exist?(base, ".mytaxa") or
          result_files_exist?(base, ".nomytaxa.txt")
        r = MiGA::Result.new("#{base}.json")
        add_files_to_ds_result(r, name, mytaxa:".mytaxa", blast:".blast",
          mytaxain:".mytaxain", nomytaxa:".nomytaxa.txt",
          species:".mytaxa.Species.txt", genus:".mytaxa.Genus.txt",
          phylum:".mytaxa.Phylum.txt", innominate:".mytaxa.innominate",
          kronain:".mytaxa.krona", krona:".html")
      else
        MiGA::Result.new("#{base}.json")
      end
    end

    ##
    # Add result type +:mytaxa_scan+ at +base+ (no +_opts+ supported).
    def add_result_mytaxa_scan(base, _opts)
      if is_nonmulti?
        return nil unless
          result_files_exist?(base, %w[.pdf .mytaxa]) or
          result_files_exist?(base, '.nomytaxa.txt')
        r = MiGA::Result.new("#{base}.json")
        add_files_to_ds_result(r, name, nomytaxa: '.nomytaxa.txt',
          mytaxa: '.mytaxa', report: '.pdf', regions_arch: '.reg.tar',
          # Intermediate / Deprecated
          blast: '.blast', mytaxain: '.mytaxain', wintax: '.wintax',
          gene_ids: '.wintax.genes', region_ids: '.wintax.regions',
          regions: '.reg')
      else
        MiGA::Result.new("#{base}.json")
      end
    end

    ##
    # Add result type +:distances+ at +base+ (no +_opts+ supported).
    def add_result_distances(base, _opts)
      if is_nonmulti?
        if is_ref?
          add_result_distances_ref(base)
        else
          add_result_distances_nonref(base)
        end
      else
        add_result_distances_multi(base)
      end
    end

    ##
    # Add result type +:taxonomy+ at +base+ (no +_opts+ supported).
    def add_result_taxonomy(base, _opts)
      add_result_distances_nonref(base)
    end

    ##
    # Add result type +:stats+ at +base+ (no +_opts+ supported).
    def add_result_stats(base, _opts)
      MiGA::Result.new("#{base}.json")
    end
    
    ##
    # Add result type +:distances+ for _multi_ datasets at +base+.
    def add_result_distances_multi(base)
      MiGA::Result.new("#{base}.json")
    end

    ##
    # Add result type +:distances+ for _nonmulti_ reference datasets at +base+.
    def add_result_distances_ref(base)
      pref = File.dirname(base)
      return nil unless
        File.exist?("#{pref}/01.haai/#{name}.db")
      r = MiGA::Result.new("#{base}.json")
      r.add_files(haai_db:"01.haai/#{name}.db", aai_db:"02.aai/#{name}.db",
        ani_db:"03.ani/#{name}.db")
      r
    end

    ##
    # Add result type +:distances+ for _nonmulti_ query datasets at +base+.
    def add_result_distances_nonref(base)
      return nil unless
        result_files_exist?(base, %w[.aai-medoids.tsv .aai.db]) or
        result_files_exist?(base, %w[.ani-medoids.tsv .ani.db])
      r = MiGA::Result.new("#{base}.json")
      add_files_to_ds_result(r, name, aai_medoids:".aai-medoids.tsv",
        haai_db:".haai.db", aai_db:".aai.db", ani_medoids:".ani-medoids.tsv",
        ani_db:".ani.db", ref_tree:".nwk", ref_tree_pdf:".nwk.pdf",
        intax_test:".intax.txt")
    end

    ##
    # Add files in +rel_files+ Hash to the result +r+ with dataset name +name+.
    def add_files_to_ds_result(r, name, rel_files)
      files = {}
      rel_files.each{ |k,v| files[k] = name + v }
      r.add_files(files)
      r
    end

end
