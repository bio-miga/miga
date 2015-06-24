#
# @package MiGA
# @author Luis M. Rodriguez-R <lmrodriguezr at gmail dot com>
# @license artistic license 2.0
# @update Jun-11-2015
#

require 'miga/metadata'
require 'miga/project'
require 'miga/result'

module MiGA
   class Dataset
      # Class
      @@RESULT_DIRS = {
	 # Preprocessing
	 :raw_reads=>'01.raw_reads', :trimmed_reads=>'02.trimmed_reads', :read_quality=>'03.read_quality',
	 :trimmed_fasta=>'04.trimmed_fasta', :assembly=>'05.assembly', :cds=>'06.cds',
	 # Annotation
	 :essential_genes=>'07.annotation/01.function/01.essential',
	 :mytaxa=>'07.annotation/02.taxonomy/01.mytaxa',
	 # Mapping
	 :mapping_on_contigs=>'08.mapping/01.read-ctg', :mapping_on_genes=>'08.mapping/02.read-gene',
	 # Distances (for single-species datasets)
	 :distances=>'09.distances'
      }
      @@KNOWN_TYPES = {
         :genome=>{:description=>"The genome from an isolate.", :multi=>false},
	 :metagenome=>{:description=>"A metagenome (excluding viromes).", :multi=>true},
	 :virome=>{:description=>"A viral metagenome.", :multi=>true},
	 :scgenome=>{:description=>"A genome from a single cell.", :multi=>false},
	 :popgenome=>{:description=>"The genome of a population (including microdiversity).", :multi=>false}
      }
      @@PREPROCESSING_TASKS = [:raw_reads, :trimmed_reads, :read_quality, :trimmed_fasta, :assembly, :cds, :essential_genes, :mytaxa, :distances]
      def self.RESULT_DIRS() @@RESULT_DIRS end
      def self.KNOWN_TYPES() @@KNOWN_TYPES end
      def self.exist?(project, name) File.exist? project.path + '/metadata/' + name + '.json' end
      def self.INFO_FIELDS() %w(name created updated type ref user description comments) end
      # Instance
      attr_reader :project, :name, :metadata
      def initialize(project, name, is_ref=true, metadata={})
	 abort "Invalid name '#{name}', please use only alphanumerics and underscores." if name !~ /^[A-Za-z0-9_]+$/
	 @project = project
	 @name = name
	 metadata[:ref] = is_ref
	 @metadata = Metadata.new self.project.path + '/metadata/' + self.name + '.json', metadata
      end
      def save
	 self.metadata[:type] = :metagenome if !self.metadata[:tax].nil? and !self.metadata[:tax][:ns].nil? and self.metadata[:tax][:ns]=='COMMUNITY'
	 self.metadata.save
	 self.load
      end
      def load
         # Nothing here...
      end
      def remove!
         self.results.each{ |r| r.remove! }
	 self.metadata.remove!
      end
      def info() Dataset.INFO_FIELDS.map{ |k| (k=='name') ? self.name : self.metadata[k.to_sym] } end
      def is_ref?() !!self.metadata[:ref] end
      def result(name)
	 return nil if @@RESULT_DIRS[name.to_sym].nil?
	 Result.load self.project.path + '/data/' + @@RESULT_DIRS[name.to_sym] + '/' + self.name + '.json'
      end
      def results() @@RESULT_DIRS.keys.map{ |k| self.result k }.compact end
      def add_result result_type
	 return nil if @@RESULT_DIRS[result_type].nil?
	 base = self.project.path + '/data/' + @@RESULT_DIRS[result_type] + '/' + self.name
	 return nil unless File.exist? base + '.done'
	 r = nil
	 case result_type
	 when :raw_reads
	    return nil unless File.exist? base + '.1.fastq' or File.exist? base + '.1.fastq.gz'
	    r = Result.new base + '.json'
	    r.data[:gz] = File.exist?(base + '.1.fastq.gz')
	    if File.exist? base + '.2.fastq' + (r.data[:gz] ? '.gz' : '')
	       r.data[:files] = {:pair1=>self.name + '.1.fastq' + (r.data[:gz] ? '.gz' : ''), :pair2=>self.name + '.2.fastq' + (r.data[:gz] ? '.gz' : '')}
	    else
	       r.data[:files] = {:single=>self.name + '.1.fastq' + (r.data[:gz] ? '.gz' : '')}
	    end
	 when :trimmed_reads
	    return nil unless File.exist?(base + '.1.clipped.fastq')
	    r = Result.new base + '.json'
	    if File.exist? base + '.2.clipped.fastq'
	       r.data[:files] = {:single1=>self.name + '.1.clipped.single.fastq', :single2=>self.name + '.2.clipped.single.fastq',
		  :pair1=>self.name + '.1.clipped.fastq', :pair2=>self.name + '.2.clipped.fastq'}
	    else
	       r.data[:files] = {:single=>self.name + '.1.clipped.fastq'}
	    end
	    self.add_result :raw_reads #-> Post gunzip (if any)
	 when :read_quality
	    return nil unless Dir.exist?(base + '.solexaqa') and Dir.exist?(base + '.fastqc')
	    r = Result.new base + '.json'
	    r.data[:files] = {:solexaqa=>self.name + '.solexaqa', :fastqc=>self.name + 'fastqc'}
	    self.add_result :trimmed_reads #-> Post cleaning
	 when :trimmed_fasta
	    return nil unless File.exist?(base + '.CoupledReads.fa') or File.exist?(base + '.SingleReads.fa')
	    r = Result.new base + '.json'
	    if File.exist?(base + '.CoupledReads.fa')
	       r.data[:files] = {:coupled=>self.name + '.CoupledReads.fa', :pair1=>self.name + '.1.fasta.gz', :pair2=>self.name + '.2.fasta.gz', :single=>self.name + '.SingleReads.fa.gz'}
	    else
	       r.data[:files] = {:single=>self.name + '.SingleReads.fa'}
	    end
	    self.add_result :raw_reads #-> Post gzip
	 when :assembly
	    return nil unless File.exist?(base + '.LargeContigs.fna') and File.exist?(base + '.AllContigs.fna')
	    r = Result.new base + '.json'
	    r.data[:files] = {:largecontigs=>self.name + '.LargeContigs.fna', :allcontigs=>self.name + '.AllContigs.fna'}
	 when :cds
	    return nil unless File.exist?(base + '.faa') and File.exist?(base + '.fna')
	    r = Result.new base + '.json'
	    r.data[:files] = {:proteins=>self.name + '.faa', :genes=>self.name + '.fna'}
	    r.data[:files][:gff2] = self.name + '.gff2.gz' if File.exist? self.name + '.gff2.gz'
	 when :essential_genes
	    return nil unless File.exist?(base + '.ess.faa') and Dir.exist?(base + '.ess') and File.exist?(base + '.ess/log')
	    r = Result.new base + '.json'
	    r.data[:files] = {:ess_genes=>self.name + '.ess.faa', :collection=>self.name + '.ess', :report=>self.name + '.ess/log'}
	 when :mytaxa
	    return nil unless File.exist?(base + '.mytaxa')
	    r = Result.new base + '.json'
	    r.data[:files] = {:mytaxa=>self.name + '.mytaxa'}
	    r.data[:gz] = File.exist?(base + '.mytaxain.gz')
	    r.data[:files][:blast] = self.name + '.blast' + (r.data[:gz] ? '.gz' : '') if File.exist?(base + '.blast' + (r.data[:gz] ? '.gz' : ''))
	    r.data[:files][:mytaxain] = self.name + '.mytaxain' + (r.data[:gz] ? '.gz' : '') if File.exist?(base + '.mytaxain' + (r.data[:gz] ? '.gz' : ''))
	 when :distances
	    r = Result.new base + '.json'
	    r.data[:files] = {}
	    r.data[:files][:haai_dir] = '01.haai/' + self.name + '.d' if Dir.exist? '01.haai/' + self.name + '.d'
	    r.data[:files][:aai_dir]  = '02.aai/'  + self.name + '.d' if Dir.exist? '02.aai/'  + self.name + '.d'
	    r.data[:files][:ani_dir]  = '03.ani/'  + self.name + '.d' if Dir.exist? '03.ani/'  + self.name + '.d'
	 end
	 r.save
	 r
      end
      def first_preprocessing() @@PREPROCESSING_TASKS.find{ |t| not self.add_result(t).nil? } end
      def next_preprocessing
         after_first = false
	 first = self.first_preprocessing
	 return nil if first.nil?
	 @@PREPROCESSING_TASKS.each do |t|
	    return t if after_first and self.add_result(t).nil?
	    after_first = (after_first or (t==first))
	 end
	 nil
      end
      def done_preprocessing?() (not self.first_preprocessing.nil?) and self.next_preprocessing.nil? end
   end
end

