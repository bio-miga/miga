
##
# Helper module including specific functions to add dataset results.
module MiGA::DatasetResult
  
  private

    ##
    # Add result type +:raw_reads+ at +base+.
    def add_result_raw_reads(base)
      return nil unless result_files_exist?(base, ".1.fastq")
      r = MiGA::Result.new(base + ".json")
      add_files_to_ds_result(r, name,
        ( result_files_exist?(base, ".2.fastq") ?
          {:pair1=>".1.fastq", :pair2=>".2.fastq"} :
          {:single=>".1.fastq"} ))
    end

    ##
    # Add result type +:trimmed_reads+ at +base+.
    def add_result_trimmed_reads(base)
      return nil unless result_files_exist?(base, ".1.clipped.fastq")
      r = MiGA::Result.new base + ".json"
      r = add_files_to_ds_result(r, name,
        {:pair1=>".1.clipped.fastq", :pair2=>".2.clipped.fastq"}) if
        result_files_exist?(base, ".2.clipped.fastq")
      r.add_file(:single, name + ".1.clipped.single.fastq")
      add_result(:raw_reads) #-> Post gunzip
      r
    end

    ##
    # Add result type +:read_quality+ at +base+.
    def add_result_read_quality(base)
      return nil unless result_files_exist?(base, %w[.solexaqa .fastqc])
      r = MiGA::Result.new(base + ".json")
      r = add_files_to_ds_result(r, name,
        {:solexaqa=>".solexaqa", :fastqc=>".fastqc"})
      add_result(:trimmed_reads) #-> Post cleaning
      r
    end

    ##
    # Add result type +:trimmed_fasta+ at +base+.
    def add_result_trimmed_fasta(base)
      return nil unless
        result_files_exist?(base, ".CoupledReads.fa") or
        result_files_exist?(base, ".SingleReads.fa") or
        result_files_exist?(base, %w[.1.fasta .2.fasta])
      r = MiGA::Result.new base + ".json"
      r = add_files_to_ds_result(r, name, {:coupled=>".CoupledReads.fa",
        :single=>".SingleReads.fa", :pair1=>".1.fasta", :pair2=>".2.fasta"})
      add_result(:raw_reads) #-> Post gzip
      r
    end

    ##
    # Add result type +:assembly+ at +base+.
    def add_result_assembly(base)
      return nil unless result_files_exist?(base, ".LargeContigs.fna")
      r = MiGA::Result.new(base + ".json")
      r = add_files_to_ds_result(r, name, {:largecontigs=>".LargeContigs.fna",
        :allcontigs=>".AllContigs.fna"})
      add_result(:trimmed_fasta) #-> Post interposing
      r
    end

    ##
    # Add result type +:cds+ at +base+.
    def add_result_cds(base)
      return nil unless result_files_exist?(base, %w[.faa .fna])
      r = MiGA::Result.new(base + ".json")
      add_files_to_ds_result(r, name, {:proteins=>".faa", :genes=>".fna",
        :gff2=>".gff2", :gff3=>".gff3", :tab=>".tab"})
    end

    ##
    # Add result type +:essential_genes+ at +base+.
    def add_result_essential_genes(base)
      return nil unless result_files_exist?(base, %w[.ess.faa .ess .ess/log])
      r = MiGA::Result.new(base + ".json")
      add_files_to_ds_result(r, name, {:ess_genes=>".ess.faa",
        :collection=>".ess", :report=>".ess/log"})
    end

    ##
    # Add result type +:ssu+ at +base+.
    def add_result_ssu(base)
      return MiGA::Result.new(base + ".json") if result(:assembly).nil?
      return nil unless result_files_exist?(base, ".ssu.fa")
      r = MiGA::Result.new(base + ".json")
      add_files_to_ds_result(r, name, {:longest_ssu_gene=>".ssu.fa",
        :gff=>".ssu.gff", :all_ssu_genes=>".ssu.all.fa"})
    end

    ##
    # Add result type +:mytaxa+ at +base+.
    def add_result_mytaxa(base)
      if is_multi?
        return nil unless result_files_exist?(base, ".mytaxa")
        r = MiGA::Result.new(base + ".json")
        add_files_to_ds_result(r, name, {:mytaxa=>".mytaxa", :blast=>".blast",
          :mytaxain=>".mytaxain"})
      else
        MiGA::Result.new base + ".json"
      end
    end

    ##
    # Add result type +:mytaxa_scan+ at +base+.
    def add_result_mytaxa_scan(base)
      if is_nonmulti?
        return nil unless
          result_files_exist?(base, %w[.pdf .wintax .mytaxa .reg])
        r = MiGA::Result.new(base + ".json")
        add_files_to_ds_result(r, name, {:mytaxa=>".mytaxa", :wintax=>".wintax",
          :blast=>".blast", :mytaxain=>".mytaxain", :report=>".pdf",
          :regions=>".reg", :gene_ids=>".wintax.genes",
          :region_ids=>".wintax.regions"})
      else
        MiGA::Result.new base + ".json"
      end
    end

    ##
    # Add result type +:distances+ at +base+.
    def add_result_distances(base)
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
    # Add result type +:stats+ at +base+.
    def add_result_stats(base)
      MiGA::Result.new(base + ".json")
    end
    
    ##
    # Add result type +:distances+ for _multi_ datasets at +base+.
    def add_result_distances_multi(base)
      MiGA::Result.new "#{base}.json"
    end

    ##
    # Add result type +:distances+ for _nonmulti_ reference datasets at +base+.
    def add_result_distances_ref(base)
      pref = File.dirname(base)
      return nil unless
        File.exist?("#{pref}/01.haai/#{name}.db")
      r = MiGA::Result.new(base + ".json")
      r.add_files({:haai_db=>"01.haai/#{name}.db",
        :aai_db=>"02.aai/#{name}.db", :ani_db=>"03.ani/#{name}.db"})
      r
    end

    ##
    # Add result type +:distances+ for _nonmulti_ query datasets at +base+.
    def add_result_distances_nonref(base)
      return nil unless
        result_files_exist?(base, %w[.aai-medoids.tsv .aai.db]) or
        result_files_exist?(base, %w[.ani-medoids.tsv .ani.db])
      r = MiGA::Result.new(base + ".json")
      add_files_to_ds_result(r, name, {
        :aai_medoids=>".aai-medoids.tsv",
        :haai_db=>".haai.db", :aai_db=>".aai.db",
        :ani_medoids=>".ani-medoids.tsv", :ani_db=>".ani.db"})
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
