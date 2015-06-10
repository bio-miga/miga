#
# @package MiGA
# @author Luis M. Rodriguez-R <lmrodriguezr at gmail dot com>
# @license artistic license 2.0
# @update Jun-10-2015
#

module MiGA
   class Taxonomy
      # Class
      @@KNOWN_RANKS = %w{ns d k p c o f g s str ds}.map{|r| r.to_sym}
      @@RANK_SYNONYMS = {
	 'namespace'=>'ns',
	 'domain'=>'d','superkingdom'=>'d',
	 'kingdom'=>'k',
	 'phylum'=>'p',
	 'class'=>'c',
	 'order'=>'o',
	 'family'=>'f',
	 'genus'=>'g',
	 'species'=>'s','sp'=>'s',
	 'strain'=>'str','isolate'=>'str', 'culture'=>'str', 'isolate'=>'str',
	 'dataset'=>'ds', 'organism'=>'ds', 'genome'=>'ds','specimen'=>'ds'
      }
      def self.KNOWN_RANKS() @@KNOWN_RANKS ; end
      def self.json_create(o) new(o['str']) ; end
      def self.normalize_rank(rank)
	 rank = rank.to_s.downcase
	 rank = @@RANK_SYNONYMS[rank] unless @@RANK_SYNONYMS[rank].nil?
	 rank = rank.to_sym
	 raise "Unknown taxonomic rank: #{rank}." unless @@KNOWN_RANKS.include? rank
	 rank
      end
      # Instance
      attr_reader :ranks
      def initialize(str, ranks=nil)
	 @ranks = {}
	 if ranks.nil?
	    if str.is_a? Array
	       self << str
	    else
	       (str + " ").scan(/([A-Za-z]+):([^:]*)( )/){ |r,n,s| self << {r=>n} }
	    end
	 else
	    ranks = ranks.split(/\s+/) unless ranks.is_a? Array
	    str = str.split(/\s/) unless str.is_a? Array
	    raise "Unequal number of ranks (#{ranks.size}) and names (#{str.size}):#{ranks} => #{str}" unless ranks.size==str.size
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
      ### Evaluates if the loaded taxonomy includes `taxon`. It assumes that `taxon`
      ### only has one informative rank. The evaluation is case-insensitive.
      def is_in? taxon
	 r = taxon.ranks.keys.first
	 return false if self[ r ].nil?
	 self[ r ].downcase == taxon[ r ].downcase
      end
      def to_s
	 @@KNOWN_RANKS.map{ |r| self.ranks[r].nil? ? nil : "#{r.to_s}:#{self.ranks[r].gsub(/\s/,'_')}" }.compact.join(" ")
      end
      def to_json(*a)
	 { JSON.create_id => self.class.name, 'str' => self.to_s }.to_json(*a)
      end
   end
end

