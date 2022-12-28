require 'open-uri'
require 'cgi'

class MiGA::RemoteDataset < MiGA::MiGA
  # Class-level
  class << self
    def UNIVERSE
      @@UNIVERSE
    end
  end
end

module MiGA::RemoteDataset::Base
  @@_EUTILS = 'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/'
  @@_EBI_API = 'https://www.ebi.ac.uk/Tools'
  @@_GTDB_API = 'https://api.gtdb.ecogenomic.org'
  @@_NCBI_API_KEY = lambda { |url|
    ENV['NCBI_API_KEY'].nil? ? url : "#{url}&api_key=#{ENV['NCBI_API_KEY']}"
  }

  ##
  # Structure of the different database Universes or containers. The structure
  # is a Hash with universe names as keys as Symbol and values being a Hash with
  # supported keys as Symbol:
  # - +:dbs+ => Hash with keys being the database name and the values a Hash of
  #   properties such as +stage+, +format+, +map_to+, and +getter+.
  # - +url+ => Pattern of the URL where the data can be obtained, where +%1$s+
  #   is the name of the database, +%2$s+ is the IDs, and +%3$s+ is format.
  #   Additional parameters can be passed to certain functions using the +extra+
  #   option.
  # - +method+ => Method used to query the URL. Only +:rest+ and +:net+ are
  #   currently supported.
  # - +api_key+ => A lambda function that takes a URL as input and returns the
  #   URL to be downloaded with an API Key (if available).
  # - +map_to_universe+ => Universe where results map to. Currently unsupported.
  @@UNIVERSE = {
    web: {
      dbs: {
        assembly: { stage: :assembly, format: :fasta },
        assembly_gz: { stage: :assembly, format: :fasta_gz },
        text: { stage: :metadata, format: :text }
      },
      url: '%2$s',
      method: :net
    },
    ebi: {
      dbs: { embl: { stage: :assembly, format: :fasta } },
      url: "#{@@_EBI_API}/dbfetch/dbfetch/%1$s/%2$s/%3$s",
      method: :rest
    },
    gtdb: {
      dbs: {
        # This is a dummy entry plugged directly to +ncbi_asm_rest+
        assembly: { stage: :assembly, format: :fasta_gz, getter: :ncbi_asm },
        # The 'taxon' namespace actually returns a list of genomes (+format+)
        taxon: {
          stage: :metadata, format: :genomes, map_to: [:assembly],
          extra: ['sp_reps_only=false']
        },
        # The 'genome' namespace actually returns the taxonomy (+format+)
        genome: { stage: :metadata, format: 'taxon-history' }
      },
      url: "#{@@_GTDB_API}/%1$s/%2$s/%3$s?%4$s",
      method: :rest,
      map_to_universe: :ncbi,
      headers: 'accept: application/json' # < TODO not currently supported
    },
    ncbi: {
      dbs: {
        nuccore: { stage: :assembly, format: :fasta, getter: :ncbi_gb },
        assembly: { stage: :assembly, format: :fasta_gz, getter: :ncbi_asm },
        taxonomy: { stage: :metadata, format: :xml }
      },
      url: "#{@@_EUTILS}efetch.fcgi?db=%1$s&id=%2$s&rettype=%3$s&retmode=text",
      method: :rest,
      api_key: @@_NCBI_API_KEY
    },
    ncbi_map: {
      dbs: {
        nuccore: {
          stage: :metadata, map_to: [:biosample, :assembly], format: :json
        },
        biosample: { stage: :metadata, map_to: [:assembly], format: :json }
      },
      url: "#{@@_EUTILS}elink.fcgi?dbfrom=%1$s&id=%2$s&db=%4$s&retmode=%3$s",
      method: :net,
      map_to_universe: :ncbi,
      api_key: @@_NCBI_API_KEY
    },
    ncbi_summary: {
      dbs: { assembly: { stage: :metadata, format: :json } },
      url: "#{@@_EUTILS}esummary.fcgi?db=%1$s&id=%2$s&retmode=%3$s",
      method: :rest,
      api_key: @@_NCBI_API_KEY
    },
    ncbi_search: {
      dbs: { assembly: { stage: :metadata, format: :json } },
      url: "#{@@_EUTILS}esearch.fcgi?db=%1$s&term=%2$s&retmode=%3$s",
      method: :rest,
      api_key: @@_NCBI_API_KEY
    }
  }
end
