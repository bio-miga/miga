#
# @package MiGA
# @author Luis M. Rodriguez-R <lmrodriguezr at gmail dot com>
# @license artistic license 2.0
# @update Mar-13-2015
#

require 'json'
require 'miga/project'

module MiGA
   class DistMatrix
      # Class
      # Instance
      attr_reader :project, :type, :result
      def initialize(project, type)
	 abort "Unsupported distance: #{type}." unless [:ani, :aai, :ssu].include? type
	 @project = project
	 @type = type
	 self.load
      end
      def load
	 @result = self.project.result("#{self.type.to_s}_distances")
	 @complete = nil
      end
      def complete?
	 return @complete unless @complete.nil?
	 incomp = Hash[ self.project.datasets.map{|ds| [ds.name, 0]} ]
	 File.open( self.result.file_path :matrix ).each do |ln|
	    next if $.==1
	    row = ln.split /\t/
	    next if row[0] == row[1]
	    incomp[row[0]] += 1
	    incomp[row[1]] += 1
	 end
	 expected = self.project.dataset.size - 1
	 incomp.delete_if{ |k,n| n==expected }
	 @missing = incomp
	 @complete = @missing.empty?
      end
      def missing
	 self.complete?
	 @missing
      end
      def missing_pairs
	 return @missing_pairs unless @missing_pairs.nil?
	 all_pairs = []
	 self.project.datasets.map{|ds|ds.name}.each do |i|
	    self.project.datasets.map{|ds|ds.name}.each do |j|
	       all_pairs << [i,j] unless i==j
	    end
	 end
	 done_pairs = []
	 File.open( self.result.file_path :matrix ).each do |ln|
	    r = ln.split /\t/
	    next if r[0] == r[1]
	    done_pairs << [r[0], r[1]]
	    done_pairs << [r[1], r[0]]
	 end
	 @missing_pairs = all_pairs - done_pairs
      end
   end
end

