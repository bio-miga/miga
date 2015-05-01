#
# @package MiGA
# @author Luis M. Rodriguez-R <lmrodriguezr at gmail dot com>
# @license artistic license 2.0
# @update Apr-30-2015
#

require 'json'
require 'fileutils'
require 'miga/dataset'

module MiGA
   class Project
      # Class
      @@FOLDERS = %w(data metadata daemon)
      @@DATA_FOLDERS = %w(
	 01.raw_reads 02.trimmed_reads 03.read_quality 04.trimmed_fasta 05.assembly 06.cds
	 07.annotation 07.annotation/01.function 07.annotation/02.taxonomy
	 07.annotation/03.qa 07.annotation/03.qa/01.checkm
	 08.mapping 08.mapping/01.read-ctg 08.mapping/02.read-gene
	 09.distances 09.distances/01.haai 09.distances/02.aai 09.distances/03.ani 09.distances/04.ssu)
      @@RESULT_DIRS = {
	 :ani_distances=>'09.distances/01.haai',
	 :ani_distances=>'09.distances/02.aai',
	 :aai_distances=>'09.distances/03.ani',
	 :ssu_distances=>'09.distances/04.ssu'
      }
      @@DISTANCES_TASKS = [:haai_distances, :aai_distances, :ani_distances, :ssu_distances]
      def self.exist?(path)
	 Dir.exist?(path) and File.exist?(path + '/miga.project.json')
      end
      def self.load(path)
	 return nil unless Project.exist? path
	 Project.new path
      end
      # Instance
      attr_reader :path, :metadata, :datasets
      def initialize(path)
         raise "Impossible to create project in uninitialized MiGA." unless File.exist? "#{ENV["HOME"]}/.miga_rc" and File.exist? "#{ENV["HOME"]}/.miga_daemon.json"
	 @path = File.absolute_path(path)
	 self.create
      end
      def create
	 Dir.mkdir self.path unless Dir.exist? self.path
	 @@FOLDERS.each{ |dir| Dir.mkdir self.path + '/' + dir unless Dir.exist? self.path + '/' + dir }
	 @@DATA_FOLDERS.each{ |dir| Dir.mkdir self.path + '/data/' + dir unless Dir.exist? self.path + '/data/' + dir }
	 @metadata = Metadata.new self.path + '/miga.project.json', {:datasets=>[], :name=>File.basename(self.path).gsub(/[^A-Za-z0-9_]/,'_')}
	 FileUtils.cp ENV["HOME"] + "/.miga_daemon.json", self.path + "/daemon/daemon.json"
	 self.save
      end
      def save
	 self.metadata.save
	 self.load
      end
      def load
	 @metadata = Metadata.load self.path + '/miga.project.json'
	 raise "Couldn't find project metadata at #{self.path}" if self.metadata.nil?
	 @datasets = self.metadata[:datasets].map{ |ds| Dataset.new self, ds }
      end
      def dataset(name) self.datasets.first{ |ds| ds.name==name } end
      def add_dataset(name)
	 self.metadata[:datasets] << name unless self.metadata[:datasets].include? name
	 self.save
	 self.dataset(name)
      end
      def unlink_dataset(name)
	 d = self.dataset name
	 return nil if d.nil?
	 self.metadata[:datasets].delete(name)
	 self.save
	 d
      end
      def result(name)
	 return nil if @@RESULT_DIRS[name.to_sym].nil?
	 Result.load self.path + '/data/' + @@RESULT_DIRS[name.to_sym] + '/result.json'
      end
      def results() @@RESULT_DIRS.keys.map{ |k| self.result k }.reject{ |r| r.nil? } end
      def add_result result_type
	 return nil if @@RESULT_DIRS[result_type].nil?
	 base = self.path + '/data/' + @@RESULT_DIRS[result_type] + '/'
	 return nil unless File.exists? base + 'done'
	 r = nil
	 case result_type
	 when :haai_distances
	    return nil unless File.exists? base + 'haai.txt'
	    r = Result.new base + 'res.json'
	    r.data[:files] = {:matrix=>'hani.txt'}
	    r.data[:files][:rbms] = 'rbm.d' if Dir.exists? base + 'rbm.d'
	    r.data[:files][:results] = 'res.d' if Dir.exists? base + 'res.d'
	 when :aai_distances
	    return nil unless File.exists? base + 'aai.txt'
	    r = Result.new base + 'res.json'
	    r.data[:files] = {:matrix=>'ani.txt'}
	    r.data[:files][:rbms] = 'rbm.d' if Dir.exists? base + 'rbm.d'
	    r.data[:files][:results] = 'res.d' if Dir.exists? base + 'res.d'
	 when :ani_distances
	    return nil unless File.exists? base + 'ani.txt'
	    r = Result.new base + 'res.json'
	    r.data[:files] = {:matrix=>'ani.txt'}
	    r.data[:files][:rbms] = 'rbm.d' if Dir.exists? base + 'rbm.d'
	    r.data[:files][:results] = 'res.d' if Dir.exists? base + 'res.d'
	 when :ssu_distances
	    return nil unless File.exists? base + 'ssu.txt'
	    r = Result.new base + 'res.json'
	    r.data[:files] = {:matrix=>'ani.txt'}
	    r.data[:files][:seqs] = 'seq.d' if Dir.exists? base + 'seq.d'
	    r.data[:files][:alns] = 'aln.d' if Dir.exists? base + 'aln.d'
	 end
	 r.save
	 r
      end
      def add_distances() @@DISTANCES_TASK.all?{ |t| self.add_result t } end
      def next_distances()
	 @@DISTANCES_TASK.find{ |t| self.add_result(t).nil? }
      end
      def unregistered_datasets()
	 datasets = []
	 MiGA::Dataset.RESULT_DIRS.each do |res, dir|
	    Dir.entries(self.path + '/data/' + dir).each do |file|
	       next unless (file =~ /\.(fa|fna|faa|fastq|fasta|fastqc|gff|gff3|done)$/) or (Dir.exists?(file) and file =~ /^[^\-\.]+$/)
	       m = /([^\.]+)/.match(file)
	       datasets << m[1] unless m.nil?
	    end
	 end
	 datasets.uniq - self.metadata[:datasets]
      end
      def done_preprocessing?() self.datasets.map{|ds| ds.done_preprocessing?}.all? end
   end
end

