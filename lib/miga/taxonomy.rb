#
# @package MiGA
# @author  Luis M. Rodriguez-R <lmrodriguezr at gmail dot com>
# @license artistic license 2.0
# @update  Oct-05-2015
#

module MiGA
   class Taxonomy
      # Class
      # Cannonical ranks
      @@KNOWN_RANKS = %w{ns d k p c o f g s ssp str ds}.map{|r| r.to_sym}
      # Synonms for cannonical ranks
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
      def self.KNOWN_RANKS() @@KNOWN_RANKS ; end
      def self.json_create(o) new(o["str"]) ; end
      def self.normalize_rank(rank)
	 rank = rank.to_s.downcase
	 return nil if rank=="no rank"
	 rank = @@RANK_SYNONYMS[rank] unless @@RANK_SYNONYMS[rank].nil?
	 rank = rank.to_sym
	 return nil unless @@KNOWN_RANKS.include? rank
	 rank
      end
      # Instance
      attr_reader :ranks
      def initialize(str, ranks=nil)
	 @ranks = {}
	 if ranks.nil?
	    if str.is_a? Array or str.is_a? Hash
	       self << str
	    else
	       (str + " ").scan(/([A-Za-z]+):([^:]*)( )/) do |r,n,s|
		  self << {r=>n}
	       end
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
      
      def <<(value)
	 if value.is_a? Array
	    value.each{ |v| self << v }
	 elsif value.is_a? String
	    (rank,name) = value.split /:/
	    self << { rank => name }
	 elsif value.is_a? Hash
	    value.each_pair do |rank, name|
	       next if name.nil? or name == ""
	       @ranks[ Taxonomy.normalize_rank rank ] = name.gsub(/_/," ")
	    end
	 else
	    raise "Unsupported class '#{value.class.name}'."
	 end
      end
      
      def [](rank) @ranks[ rank.to_sym ] ; end
      
      ### Evaluates if the loaded taxonomy includes `taxon`. It assumes that
      ### `taxon` only has one informative rank. The evaluation is
      ### case-insensitive.
      def is_in? taxon
	 r = taxon.ranks.keys.first
	 return false if self[ r ].nil?
	 self[ r ].downcase == taxon[ r ].downcase
      end
      
      ### Sorted list of ranks, as two-entry arrays
      def sorted_ranks
	 @@KNOWN_RANKS.map do |r|
	    ranks[r].nil? ? nil : [r, ranks[r]]
	 end.compact
      end

      def highest; sorted_ranks.first ; end

      def lowest; sorted_ranks.last ; end
      
      def to_s
	 sorted_ranks.map{ |r| "#{r[0].to_s}:#{r[1].gsub(/\s/,"_")}" }.join(" ")
      end
      
      def to_json(*a)
	 { JSON.create_id => self.class.name, "str" => self.to_s }.to_json(*a)
      end
   end
end

