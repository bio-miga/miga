#
# @package EGR (codename)
# @author Luis M. Rodriguez-R <lmrodriguezr at gmail dot com>
# @license artistic license 2.0
# @update Dec-2-2014
#

require 'JSON'
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
      def self.KNOWN_TYPES() @@KNOWN_TYPES end
      def self.exist?(project, name) File.exist? project.path + '/metadata/' + name + '.json' end
      # Instance
      attr_reader :project, :name, :metadata
      def initialize(project, name)
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
      def result(name)
	 return nil if @@RESULT_DIRS[name.to_sym].nil?
	 Result.load self.project.path + '/data/' + @@RESULT_DIRS[name.to_sym] + '/' + self.name + '.json'
      end
      def results() @@RESULT_DIRS.keys.map{ |k| self.result k }.reject{ |r| r.nil? } end
      def add_result result_type
	 return nil if @@RESULT_DIRS[result_type].nil?
	 base = self.project.path + '/data/' + @@RESULT_DIRS[result_type] + '/' + self.name
	 r = nil
	 case result_type
	 when :raw_reads
	    return nil unless File.exist? base + '.1.fastq.gz'
	    r = Result.new base + '.json'
	    if File.exist? base + '.2.fastq.gz'
	       r.data[:files] = {:pair1=>base + '.1.fastq.gz', :pair2=>base + '.1.fastq.gz'}
	    else
	       r.data[:files] = {:single=>base + '.1.fastq.gz'}
	    end
	 when :trimmed_reads
	    return nil unless File.exist?(base + '.1.clipped.fastq') or File.exist?(base + '1.clipped.single.fastq')
	    r = Result.new base + '.json'
	    r.data[:files] = {:single=>base + '.1.clipped.single.fastq'}
	    if File.exist? base + '.2.clipped.fastq'
	       r.data[:files][:pair1] = base + '.1.clipped.fastq'
	       r.data[:files][:pair2] = base + '.2.clipped.fastq'
	    end
	 when :read_quality
	    return nil unless Dir.exist? base
	    r = Result.new base + '.json'
	    r.data[:files] = {:solexaqa=>base}
	    r.data[:files][:fastqc] = base + '.fastqc' if Dir.exist? base + '.fastqc'
	 when :trimmed_fasta
	    return nil unless File.exist?(base + '.CoupledReads.fa') or File.exist?(base + '.SingleReads.fa')
	    r = Result.new base + '.json'
	    if File.exist?(base + '.CoupledReads.fa')
	       r.data[:files] = {:coupled=>base + '.CoupledReads.fa'}
	       r.data[:files][:pair1] = base + '.1.fa' if File.exist? base + '.1.fa'
	       r.data[:files][:pair2] = base + '.2.fa' if File.exist? base + '.2.fa'
	    else
	       r.data[:files] = {:single=>base + '.SingleReads.fa'}
	    end
	 when :assembly
	    return nil unless File.exist? base + '.LargeContigs.fna'
	    r = Result.new base + '.json'
	    r.data[:files] = {:largecontigs=>base + '.LargeContigs.fna'}
	    r.data[:files][:allcontigs] = base + '.AllContigs.fna' if File.exist? base + '.AllContigs.fna'
	 when :cds
	    return nil unless File.exist?(base + '.faa') and File.exist?(base + '.gff2') and File.exist?(base + '.fna')
	    r = Result.new base + '.json'
	    r.data[:files] = {:proteins=>base + '.faa', :genes=>base + '.fna', :gff2=>base + '.gff2'}
	 end
	 r.save
	 r
      end
      def add_preprocessing
	 [:raw_reads, :trimmed_reads, :read_quality, :trimmed_fasta, :assembly, :cds].all?{ |t| self.add_result t }
      end
   end
end

