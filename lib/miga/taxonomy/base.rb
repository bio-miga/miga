# @package MiGA
# @license Artistic-2.0

class MiGA::Taxonomy < MiGA::MiGA
  class << self
    ##
    # Returns cannonical rank (Symbol) for the +rank+ String
    def normalize_rank(rank)
      return unless rank
      return rank.to_sym if @@_KNOWN_RANKS_H[rank.to_sym]

      rank = rank.to_s.downcase
      return if rank == 'no rank'

      rank = @@RANK_SYNONYMS[rank] unless @@RANK_SYNONYMS[rank].nil?
      rank = rank.to_sym
      return unless @@_KNOWN_RANKS_H[rank]

      rank
    end

    ##
    # Initialize from JSON-derived Hash +o+
    def json_create(o)
      new(o['str'], nil, o['alt'])
    end

    def KNOWN_RANKS()
      @@KNOWN_RANKS
    end

    def LONG_RANKS()
      @@LONG_RANKS
    end
  end
end

module MiGA::Taxonomy::Base
  ##
  # Cannonical ranks
  @@KNOWN_RANKS = %w{ns d k p c o f g s ssp str ds}.map { |r| r.to_sym }
  @@_KNOWN_RANKS_H = Hash[@@KNOWN_RANKS.map { |i| [i, true] }]

  ##
  # Long names of the cannonical ranks
  @@LONG_RANKS = {
    root: 'root', ns: 'namespace', d: 'domain', k: 'kingdom',
    p: 'phylum', c: 'class', o: 'order', f: 'family', g: 'genus', s: 'species',
    ssp: 'subspecies', str: 'strain', ds: 'dataset'
  }

  ##
  # Synonms for cannonical ranks
  @@RANK_SYNONYMS = {
    'namespace' => 'ns',
    'domain' => 'd', 'superkingdom' => 'd',
    'kingdom' => 'k',
    'phylum' => 'p',
    'class' => 'c',
    'order' => 'o',
    'family' => 'f',
    'genus' => 'g',
    'species' => 's', 'sp' => 's',
    'subspecies' => 'ssp',
    'strain' => 'str', 'isolate' => 'str', 'culture' => 'str',
    'dataset' => 'ds', 'organism' => 'ds', 'genome' => 'ds', 'specimen' => 'ds'
  }
end
