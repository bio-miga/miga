# @package MiGA
# @license Artistic-2.0

##
# Taxonomic classifications in MiGA.
class MiGA::Taxonomy < MiGA::MiGA
  # Class-level

  ##
  # Cannonical ranks.
  def self.KNOWN_RANKS() @@KNOWN_RANKS ; end
  @@KNOWN_RANKS = %w{ns d k p c o f g s ssp str ds}.map{|r| r.to_sym}
  @@_KNOWN_RANKS_H = Hash[ @@KNOWN_RANKS.map{ |i| [i,true] } ]

  ##
  # Long names of the cannonical ranks.
  def self.LONG_RANKS() @@LONG_RANKS ; end
  @@LONG_RANKS = {root: "root", ns: "namespace", d: "domain", k: "kingdom",
    p: "phylum", c: "class", o: "order", f: "family", g: "genus", s: "species",
    ssp: "subspecies", str: "strain", ds: "dataset"}

  ##
  # Synonms for cannonical ranks.
  @@RANK_SYNONYMS = {
    "namespace"=>"ns",
    "domain"=>"d","superkingdom"=>"d",
    "kingdom"=>"k",
    "phylum"=>"p",
    "class"=>"c",
    "order"=>"o",
    "family"=>"f",
    "genus"=>"g",
    "species"=>"s","sp"=>"s",
    "subspecies"=>"ssp",
    "strain"=>"str","isolate"=>"str","culture"=>"str",
    "dataset"=>"ds","organism"=>"ds","genome"=>"ds","specimen"=>"ds"
  }

  ##
  # Initialize from JSON-derived Hash +o+.
  def self.json_create(o) new(o["str"]) ; end

  ##
  # Returns cannonical rank (Symbol) for the +rank+ String.
  def self.normalize_rank(rank)
    return rank.to_sym if @@_KNOWN_RANKS_H[rank.to_sym]
    rank = rank.to_s.downcase
    return nil if rank=="no rank"
    rank = @@RANK_SYNONYMS[rank] unless @@RANK_SYNONYMS[rank].nil?
    rank = rank.to_sym
    return nil unless @@_KNOWN_RANKS_H[rank]
    rank
  end

  # Instance-level

  ##
  # Taxonomic hierarchy Hash.
  attr_reader :ranks

  ##
  # Create MiGA::Taxonomy from String or Array +str+. The string is a series of
  # space-delimited entries, the array is a vector of entries. Each entry can be
  # either a rank:value pair (if +ranks+ is nil), or just values in the same
  # order as ther ranks in +ranks+. Alternatively, +str+ as a Hash with rank =>
  # value pairs is also supported.
  def initialize(str, ranks=nil)
    @ranks = {}
    if ranks.nil?
      case str when Array, Hash
        self << str
      else
        "#{str} ".scan(/([A-Za-z]+):([^:]*)( )/){ |r,n,_| self << {r=>n} }
      end
    else
      ranks = ranks.split(/\s+/) unless ranks.is_a? Array
      str = str.split(/\s/) unless str.is_a? Array
      raise "Unequal number of ranks (#{ranks.size}) " +
        "and names (#{str.size}):#{ranks} => #{str}" unless
        ranks.size==str.size
      (0 .. str.size).each{ |i| self << "#{ranks[i]}:#{str[i]}" }
    end
  end
  
  ##
  # Add +value+ to the hierarchy, that can be an Array, a String, or a Hash, as
  # described in #initialize.
  def <<(value)
    if value.is_a? Hash
      value.each_pair do |rank_i, name_i|
        next if name_i.nil? or name_i == ""
        @ranks[ Taxonomy.normalize_rank rank_i ] = name_i.tr("_"," ")
      end
    elsif value.is_a? Array
      value.each{ |v| self << v }
    elsif value.is_a? String
      (rank, name) = value.split(/:/)
      self << { rank => name }
    else
      raise "Unsupported class: #{value.class.name}."
    end
  end
  
  ##
  # Get +rank+ value.
  def [](rank) @ranks[ rank.to_sym ] ; end
  
  ##
  # Evaluates if the loaded taxonomy includes +taxon+. It assumes that +taxon+
  # only has one informative rank. The evaluation is case-insensitive.
  def is_in? taxon
    r = taxon.ranks.keys.first
    return false if self[ r ].nil?
    self[ r ].downcase == taxon[ r ].downcase
  end

  ##
  # Sorted list of ranks, as an Array of two-entry Arrays (rank and value).
  def sorted_ranks
    @@KNOWN_RANKS.map do |r|
      ranks[r].nil? ? nil : [r, ranks[r]]
    end.compact
  end
  
  ##
  # Get the most general rank as a two-entry Array (rank and value).
  def highest; sorted_ranks.first ; end

  ##
  # Get the most specific rank as a two-entry Array (rank and value).
  def lowest; sorted_ranks.last ; end
  
  ##
  # Generate cannonical String for the taxonomy.
  def to_s
    sorted_ranks.map{ |r| "#{r[0]}:#{r[1].gsub(/\s/,"_")}" }.join(" ")
  end
  
  ##
  # Generate JSON-formated String representing the taxonomy.
  def to_json(*a)
    { JSON.create_id => self.class.name, "str" => self.to_s }.to_json(*a)
  end
  
end
