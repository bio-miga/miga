# @package MiGA
# @license Artistic-2.0

require 'miga/taxonomy/base'

##
# Taxonomic classifications in MiGA.
class MiGA::Taxonomy < MiGA::MiGA
  include MiGA::Taxonomy::Base

  ##
  # Taxonomic hierarchy Hash.
  attr_reader :ranks

  ##
  # Create MiGA::Taxonomy from String or Array +str+. The string is a series of
  # space-delimited entries, the array is a vector of entries. Each entry can be
  # either a rank:value pair (if +ranks+ is nil), or just values in the same
  # order as ther ranks in +ranks+. Alternatively, +str+ as a Hash with rank =>
  # value pairs is also supported. If +alt+ is passed, it must be an Array of
  # String, Array, or Hash entries as defined above (except +ranks+ are not
  # allowed).
  def initialize(str, ranks = nil, alt = [])
    @ranks = {}
    if ranks.nil?
      initialize_by_str(str)
    else
      initialize_by_ranks(str, ranks)
    end
    @alt = (alt || []).map { |i| Taxonomy.new(i) }
  end

  ##
  # Add +value+ to the hierarchy, that can be an Array, a String, or a Hash, as
  # described in #initialize.
  def <<(value)
    case value
    when Hash
      value.each do |r, n|
        next if n.nil? or n == ''
        @ranks[ self.class.normalize_rank(r) ] = n.tr('_', ' ')
      end
    when Array
      value.each { |v| self << v }
    when String
      self << Hash[*value.split(':', 2)]
    else
      raise 'Unsupported class: ' + value.class.name
    end
  end

  ##
  # Get +rank+ value.
  def [](rank) @ranks[rank.to_sym]; end

  ##
  # Get the alternative taxonomies.
  # - If +which+ is nil (default), returns all alternative taxonomies as Array
  #   (not including the master taxonomy).
  # - If +which+ is Integer, returns the indexed taxonomy
  #   (starting with 0, the master taxonomy).
  # - Otherwise, returns the first taxonomy with namespace +which+ (coerced as
  #   String), including the master taxonomy.
  # In the latter two cases it can be nil.
  def alternative(which = nil)
    case which
    when nil
      @alt
    when Integer
      ([self] + @alt)[which]
    else
      ([self] + @alt).find { |i| i.namespace.to_s == which.to_s }
    end
  end

  ##
  # Evaluates if the loaded taxonomy includes +taxon+. It assumes that +taxon+
  # only has one informative rank. The evaluation is case-insensitive.
  def in?(taxon)
    r = taxon.ranks.keys.first
    return false if self[r].nil?
    self[r].casecmp(taxon[r]).zero?
  end

  ##
  # Sorted list of ranks, as an Array of two-entry Arrays (rank and value).
  # If +force_ranks+ is true, it returns all standard ranks even if undefined.
  # If +with_namespace+ is true, it includes also the namespace.
  def sorted_ranks(force_ranks = false, with_namespace = false)
    @@KNOWN_RANKS.map do |r|
      next if
        (r == :ns and not with_namespace) or (ranks[r].nil? and not force_ranks)
      [r, ranks[r]]
    end.compact
  end

  ##
  # Namespace of the taxonomy (a String) or +nil+.
  def namespace; self[ :ns ] ; end
  
  ##
  # Get the most general rank as a two-entry Array (rank and value).
  # If +force_ranks+ is true, it always returns the value for domain (d)
  # even if undefined.
  def highest(force_ranks = false)
    sorted_ranks(force_ranks).first
  end

  ##
  # Get the most specific rank as a two-entry Array (rank and value).
  # If +force_ranks+ is true, it always returns the value for dataset (ds)
  # even if undefined.
  def lowest(force_ranks = false)
    sorted_ranks(force_ranks).last
  end
  
  ##
  # Generate cannonical String for the taxonomy. If +force_ranks+ is true,
  # it returns all the standard ranks even if undefined.
  def to_s(force_ranks = false)
    sorted_ranks(force_ranks, true).
      map { |r| "#{r[0]}:#{(r[1] || '').gsub(/[\s:]/, '_')}" }.join(' ')
  end
  
  ##
  # Generate JSON-formated String representing the taxonomy.
  def to_json(*a)
    hsh = { JSON.create_id => self.class.name, 'str' => self.to_s }
    hsh['alt'] = alternative.map(&:to_s) unless alternative.empty?
    hsh.to_json(*a)
  end

  private

    def initialize_by_str(str)
      case str
      when Array, Hash
        self << str
      else
        "#{str} ".scan(/([A-Za-z]+):([^:]*)( )/){ |r, n, _| self << { r => n } }
      end
    end

    def initialize_by_ranks(str, ranks)
      ranks = ranks.split(/\s+/) unless ranks.is_a? Array
      str = str.split(/\s+/) unless str.is_a? Array
      unless ranks.size == str.size
        raise "Unequal number of ranks and names: #{ranks} => #{str}"
      end
      str.each_with_index { |i, k| self << "#{ranks[k]}:#{i}" }
    end
  
end
