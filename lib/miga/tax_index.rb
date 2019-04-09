# @package MiGA
# @license Artistic-2.0

require "miga/taxonomy"

##
# Indexing methods based on taxonomy.
class MiGA::TaxIndex < MiGA::MiGA
  
  # Instance-level
  
  ##
  # Datasets in the index.
  attr_reader :datasets
  # Taxonomy root.
  attr_reader :root

  ##
  # Initialize an empty MiGA::TaxIndex
  def initialize
    @root = MiGA::TaxIndexTaxon.new :root, "biota"
    @datasets = []
  end

  ##
  # Index +dataset+, a MiGA::Dataset object.
  def <<(dataset)
    return nil if dataset.metadata[:tax].nil?
    taxon = @root
    MiGA::Taxonomy.KNOWN_RANKS.each do |rank|
      taxon = taxon.add_child(rank, dataset.metadata[:tax][rank])
    end
    taxon.add_dataset dataset
    @datasets << dataset
  end

  ##
  # Finds all the taxa in the collection at the +rank+ taxonomic rank.
  def taxa_by_rank(rank)
    rank = MiGA::Taxonomy.normalize_rank(rank)
    taxa = [@root]
    select = []
    loop do
      new_taxa = []
      taxa.map{ |tx| tx.children }.flatten.each do |ch|
        if ch.rank == rank
          select << ch
        elsif not ch.children.empty?
          new_taxa << ch
        end
      end
      break if new_taxa.empty?
    end
    select
  end

  ##
  # Generate JSON String for the index.
  def to_json
    MiGA::Json.generate(
      { root: root.to_hash, datasets: datasets.map{ |d| d.name } })
  end

  ##
  # Generate tabular String for the index.
  def to_tab(unknown=false) ; root.to_tab(unknown) ; end
end

##
# Helper class for MiGA::TaxIndex.
class MiGA::TaxIndexTaxon < MiGA::MiGA
  
  # Instance-level
  
  ##
  # Rank of the taxon.
  attr_reader :rank
  # Name of the taxon.
  attr_reader :name
  # Children of the taxon.
  attr_reader :children
  # Datasets directly classified at the taxon (not at children).
  attr_reader :datasets

  ##
  # Initalize taxon at +rank+ with +name+.
  def initialize(rank, name)
    @rank = rank.to_sym
    @name = (name.nil? ? nil : name.miga_name)
    @children = []
    @datasets = []
  end

  ##
  # String representation of the taxon.
  def tax_str ; "#{rank}:#{name.nil? ? "?" : name}" ; end

  ##
  # Add child at +rank+ with +name+.
  def add_child(rank, name)
    rank = rank.to_sym
    name = name.miga_name unless name.nil?
    child = children.find{ |it| it.rank==rank and it.name==name }
    if child.nil?
      child = MiGA::TaxIndexTaxon.new(rank, name)
      @children << child
    end
    child
  end

  ##
  # Add dataset at the current taxon (not children).
  def add_dataset(dataset) @datasets << dataset ; end

  ##
  # Get the number of datasets in the taxon (including children).
  def datasets_count
    children.map{ |it| it.datasets_count }.reduce(datasets.size, :+)
  end

  ##
  # Get all the datasets in the taxon (including children).
  def all_datasets
    children.map{ |it| it.datasets }.reduce(datasets, :+)
  end

  ##
  # JSON String of the taxon.
  def to_json(*a)
    { str:tax_str, datasets:datasets.map{|d| d.name},
      children:children }.to_json(a)
  end

  ##
  # Hash representation of the taxon.
  def to_hash
    { str:tax_str, datasets:datasets.map{|d| d.name},
      children:children.map{ |it| it.to_hash } }
  end

  ##
  # Tabular String of the taxon.
  def to_tab(unknown, indent=0)
    o = ""
    o = "#{" " * indent}#{tax_str}: #{datasets_count}\n" if
      unknown or not datasets.empty? or not name.nil?
    indent += 2
    datasets.each{ |ds| o << "#{" " * indent}# #{ds.name}\n" }
    children.each{ |it| o << it.to_tab(unknown, indent) }
    o
  end

end
