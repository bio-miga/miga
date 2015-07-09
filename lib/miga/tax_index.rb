
# @package MiGA
# @author Luis M. Rodriguez-R <lmrodriguezr at gmail dot com>
# @license artistic license 2.0
# @update Jul-09-2015
#

require 'miga/taxonomy'

module MiGA
   class TaxIndex
      # Instance
      attr_reader :datasets, :root
      def initialize()
	 @root = TaxIndexTaxon.new :root, "biota"
	 @datasets = []
      end
      def <<(dataset)
         return nil if dataset.metadata[:tax].nil?
	 taxon = @root
	 Taxonomy.KNOWN_RANKS.each { |rank| taxon = taxon.add_child(rank, dataset.metadata[:tax][rank]) }
	 taxon.add_dataset dataset
	 @datasets << dataset
      end
      def to_json
	 JSON.pretty_generate({ root:root.to_hash, datasets:datasets.map{|d| d.name} })
      end
      def to_tab(unknown=false) ; root.to_tab(unknown) ; end
   end
   class TaxIndexTaxon
      # Instance
      attr_reader :rank, :name,:children, :datasets
      def initialize(rank, name)
	 @rank = rank.to_sym
	 @name = (name.nil? ? nil : name.miga_name)
	 @children = []
	 @datasets = []
      end
      def tax_str ; "#{rank}:#{name.nil? ? "?" : name}" ; end
      def add_child(rank, name)
	 rank = rank.to_sym
	 name = name.miga_name unless name.nil?
         child = children.find{ |it| it.rank==rank and it.name==name }
	 if child.nil?
	    child = TaxIndexTaxon.new(rank, name)
	    @children << child
	 end
	 child
      end
      def add_dataset(dataset) @datasets << dataset ; end
      def datasets_count
	 datasets.size + children.map{ |it| it.datasets_count }.reduce(0, :+)
      end
      def to_json(*a)
	 { str:tax_str, datasets:datasets.map{|d| d.name}, children:children }.to_json(a)
      end
      def to_hash
         { str:tax_str, datasets:datasets.map{|d| d.name}, children:children.map{ |it| it.to_hash } }
      end
      def to_tab(unknown, indent=0)
	 o = ""
	 o = (" " * indent) + tax_str + ": " + datasets_count.to_s + "\n" if unknown or not datasets.empty? or not name.nil?
	 indent += 2
	 datasets.each{ |ds| o += (" " * indent) + "# " + ds.name + "\n" }
	 children.each{ |it| o += it.to_tab(unknown, indent) }
	 o
      end
   end
end

