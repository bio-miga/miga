# frozen_string_literal: true

module MiGA::Dataset::Result::Add
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
      fastaai_index_2: '.faix',
      fastaai_crystal: '.crystal'
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

  private

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
