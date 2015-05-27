#
# @package MiGA
# @author Luis M. Rodriguez-R <lmrodriguezr at gmail dot com>
# @license artistic license 2.0
# @update May-27-2015
#

require 'json'

module MiGA
   class Taxonomy
      # Class
      @@KNOWN_RANKS = %w{domain phylum class order family genus species}.map{|r| r.to_sym}
      def self.KNOWN_RANKS() @@KNOWN_RANKS ; end
      def self.json_create(o) new(o['str']) ; end
      # Instance
      attr_reader :ranks
      def initialize(str, ranks=nil)
	 @ranks = {}
	 if ranks.nil?
	    if str.is_a? Array
	       self << str
	    else
	       (str + " ").scan(/\w+:[^:]+ /){ |m| self << m.sub(/\s+$/,"") }
	    end
	 else
	    ranks = ranks.split(/\s+/) unless ranks.is_a? Array
	    str = str.split(/\s/) unless str.is_a? Array
	    raise "Unequal number of ranks (#{ranks.size}) and names (#{str.size})." unless ranks.size==str.size
	    (0 .. str.size).each{ |i| self << "#{ranks[i]}:#{str[i]}" }
	 end
      end
      def <<(value)
	 if value.is_a? Array
	    value.each{ |v| self << v }
	    return nil
	 end
	 (rank,name) = value.split /:/
	 return nil if name.nil? or name == ""
	 rank.downcase!
	 rank = "domain" if rank == "superkingdom"
	 rank = rank.to_sym
	 raise "Unknown taxonomic rank: #{rank}." unless @@KNOWN_RANKS.include? rank
	 @ranks[ rank ] = name.gsub(/_/," ")
      end
      def [](rank) @ranks[ rank.to_sym ] ; end
      def to_s
	 @@KNOWN_RANKS.map{ |r| self.ranks[r].nil? ? nil : "#{r.to_s}:#{self.ranks[r].gsub(/\s/,'_')}" }.compact.join(" ")
      end
      def to_json(*a)
	 { JSON.create_id => self.class.name, 'str' => self.to_s }.to_json(*a)
      end
   end
end

