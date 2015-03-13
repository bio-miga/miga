#
# @package EGR (codename)
# @author Luis M. Rodriguez-R <lmrodriguezr at gmail dot com>
# @license artistic license 2.0
# @update Mar-03-2015
#

require 'json'
require 'egr/metadata'
require 'egr/project'
require 'egr/result'

module EGR
   class Dataset
      # Class
      @@RESULT_DIRS = {
	 # Preprocessing
	 :raw_reads=>'01.raw_reads', :trimmed_reads=>'02.trimmed_reads', :read_quality=>'03.read_quality',
	 :trimmed_fasta=>'04.trimmed_fasta', :assembly=>'05.assembly', :cds=>'06.cds',
	 # Annotation
	 :functional_annotation=>'07.annotation/01.function', :taxonomic_annotation=>'07.annotation/02.taxonomy',
	 # Mapping
	 :mapping_on_contigs=>'08.mapping/01.read-ctg', :mapping_on_genes=>'08.mapping/02.read-gene'
      }
      @@KNOWN_TYPES = {
         :genome=>{:description=>"The genome from an isolate."},
	 :metagenome=>{:description=>"A metagenome (excluding viromes)."},
	 :virome=>{:description=>"A viral metagenome."},
	 :scgenome=>{:description=>"A genome from a single cell."},
	 :popgenome=>{:description=>"The genome of a population (including microdiversity)."}
      }
      @@PREPROCESSING_TASKS = [:raw_reads, :trimmed_reads, :read_quality, :trimmed_fasta, :assembly, :cds]
      def self.KNOWN_TYPES() @@KNOWN_TYPES end
      def self.RESULT_DIRS() @@RESULT_DIRS end
      def self.exist?(project, name) File.exist? project.path + '/metadata/' + name + '.json' end
      def self.INFO_FIELDS() %w(name created updated type user description comments) end
      # Instance
      attr_reader :project, :name, :metadata
      def initialize(project, name)
	 abort "Invalid name '#{name}', please use only alphanumerics and underscores." if name !~ /^[A-Za-z0-9_]+$/
	 @project = project
	 @name = name
	 @metadata = Metadata.new self.project.path + '/metadata/' + self.name + '.json'
      end
      def save
	 self.metadata.save
	 self.load
      end
      def load
         # Nothing here...
      end
      def remove!
         self.results.remove!
	 self.metadata.remove!
      end
      def info
         EGR::Dataset.INFO_FIELDS.map{ |k| (k=='name') ? self.name : self.metadata[k.to_sym] }
      end
      def result(name)
	 return nil if @@RESULT_DIRS[name.to_sym].nil?
	 Result.load self.project.path + '/data/' + @@RESULT_DIRS[name.to_sym] + '/' + self.name + '.json'
      end
      def results() @@RESULT_DIRS.keys.map{ |k| self.result k }.compact end
      def add_result result_type
	 return nil if @@RESULT_DIRS[result_type].nil?
	 base = self.project.path + '/data/' + @@RESULT_DIRS[result_type] + '/' + self.name
	 r = nil
	 return nil unless File.exists? base + '.done'
	 case result_type
	 when :raw_reads
	    return nil unless File.exist? base + '.1.fastq.gz'
	    r = Result.new base + '.json'
	    if File.exist? base + '.2.fastq.gz'
	       r.data[:files] = {:pair1=>self.name + '.1.fastq.gz', :pair2=>self.name + '.1.fastq.gz'}
	    else
	       r.data[:files] = {:single=>self.name + '.1.fastq.gz'}
	    end
	 when :trimmed_reads
	    return nil unless File.exist?(base + '.1.clipped.fastq') or File.exist?(base + '1.clipped.single.fastq')
	    r = Result.new base + '.json'
	    r.data[:files] = {:single=>self.name + '.1.clipped.single.fastq'}
	    if File.exist? base + '.2.clipped.fastq'
	       r.data[:files][:pair1] = self.name + '.1.clipped.fastq'
	       r.data[:files][:pair2] = self.name + '.2.clipped.fastq'
	    end
	 when :read_quality
	    return nil unless Dir.exist? base
	    r = Result.new base + '.json'
	    r.data[:files] = {:solexaqa=>self.name}
	    r.data[:files][:fastqc] = self.name + '.fastqc' if Dir.exist? base + '.fastqc'
	 when :trimmed_fasta
	    return nil unless File.exist?(base + '.CoupledReads.fa') or File.exist?(base + '.SingleReads.fa')
	    r = Result.new base + '.json'
	    if File.exist?(base + '.CoupledReads.fa')
	       r.data[:files] = {:coupled=>self.name + '.CoupledReads.fa'}
	       r.data[:files][:pair1] = self.name + '.1.fa' if File.exist? base + '.1.fa'
	       r.data[:files][:pair2] = self.name + '.2.fa' if File.exist? base + '.2.fa'
	    else
	       r.data[:files] = {:single=>self.name + '.SingleReads.fa'}
	    end
	 when :assembly
	    return nil unless File.exist? base + '.LargeContigs.fna'
	    r = Result.new base + '.json'
	    r.data[:files] = {:largecontigs=>self.name + '.LargeContigs.fna'}
	    r.data[:files][:allcontigs] = self.name + '.AllContigs.fna' if File.exist? base + '.AllContigs.fna'
	 when :cds
	    return nil unless File.exist?(self.name + '.faa') and File.exist?(base + '.gff2') and File.exist?(base + '.fna')
	    r = Result.new base + '.json'
	    r.data[:files] = {:proteins=>self.name + '.faa', :genes=>self.name + '.fna', :gff2=>self.name + '.gff2'}
	 end
	 r.save
	 r
      end
      def add_preprocessing
	 @@PREPROCESSING_TASKS.all?{ |t| self.add_result t }
      end
      def first_preprocessing
         @@PREPROCESSING_TASKS.find{ |t| not self.add_result(t).nil? }
      end
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
   end
end

