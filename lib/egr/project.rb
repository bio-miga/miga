#
# @package EGR (codename)
# @author Luis M. Rodriguez-R <lmrodriguezr at gmail dot com>
# @license artistic license 2.0
# @update Dec-2-2014
#

require 'JSON'
require 'egr/dataset'

module EGR
   class Project
      # Class
      @@FOLDERS = %w(data metadata)
      @@DATA_FOLDERS = %w(
	 01.raw_reads 02.trimmed_reads 03.read_quality 04.trimmed_fasta 05.assembly 06.cds
	 07.annotation 07.annotation/01.function 07.annotation/02.taxonomy
	 08.mapping 08.mapping/01.read-ctg 08.mapping/02.read-gene
	 09.distances 09.distances/01.aai 09.distances/02.ani 09.distances/03.ssu)
      @@RESULT_DIRS = {
	 :ani_distances=>'09.distances/01.ani',
	 :aai_distances=>'09.distances/02.aai',
	 :ssu_distances=>'09.distances/03.ssu'
      }
      def self.exist?(path)
	 Dir.exist?(path) and File.exist?(path + '/egr.project.json')
      end
      def self.load(path)
	 return nil unless Project.exist? path
	 Project.new path
      end
      # Instance
      attr_reader :path, :metadata, :datasets
      def initialize(path)
         @path = path
	 if Project.exist? self.path
	    self.load
	 else
	    self.create
	 end
      end
      def create
         Dir.mkdir self.path
	 @@FOLDERS.each{ |dir| Dir.mkdir self.path + '/' + dir }
	 @@DATA_FOLDERS.each{ |dir| Dir.mkdir self.path + '/data/' + dir }
	 @metadata = Metadata.new self.path + '/egr.project.json', {:datasets=>[]}
	 self.save
      end
      def save
	 self.metadata.save
	 self.load
      end
      def load
	 @metadata = Metadata.load self.path + '/egr.project.json'
	 raise "Couldn't find project metadata at #{self.path}" if self.metadata.nil?
	 @datasets = self.metadata[:datasets].map{ |ds| Dataset.new self, ds }
      end
      def dataset(name) self.datasets.first{ |ds| ds.name==name } end
      def add_dataset(name)
         self.metadata[:datasets] << name
	 self.save
	 self.dataset(name)
      end
      def result(name)
	 return nil if @@RESULT_DIRS[name.to_sym].nil?
	 Result.load self.path + '/data/' + @@RESULT_DIRS[name.to_sym] + '/result.json'
      end
      def results() @@RESULT_DIRS.keys.map{ |k| self.result k }.reject{ |r| r.nil? } end
   end
end

