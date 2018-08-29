
require 'restclient'
require 'open-uri'

class MiGA::RemoteDataset < MiGA::MiGA

  # Class-level
  class << self
    def UNIVERSE ; @@UNIVERSE ; end
  end

end

module MiGA::RemoteDataset::Base

  @@_EUTILS = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/"

  ##
  # Structure of the different database Universes or containers. The structure
  # is a Hash with universe names as keys as Symbol and values being a Hash with
  # supported keys as Symbol:
  # - +:dbs+ => Hash with keys being the database name and the values a Hash of
  #   properties such as +stage+, +format+, and +map_to+.
  # - +url+ => Pattern of the URL where the data can be obtained, where +%1$s+
  #   is the name of the database, +%2$s+ is the IDs, and +%3$s+ is format.
  # - +method+ => Method used to query the URL. Only +:rest+ is currently
  #   supported.
  # - +map_to_universe+ => Universe where results map to. Currently unsupported.
  @@UNIVERSE = {
    web:{
      dbs: {
        assembly:{stage: :assembly, format: :fasta},
        assembly_gz:{stage: :assembly, format: :fasta_gz}
      },
      url: "%2$s",
      method: :net
    },
    ebi:{
      dbs: { embl:{stage: :assembly, format: :fasta} },
      url: "http://www.ebi.ac.uk/Tools/dbfetch/dbfetch/%1$s/%2$s/%3$s",
      method: :rest
    },
    ncbi:{
      dbs: { nuccore:{stage: :assembly, format: :fasta} },
      url: "#{@@_EUTILS}efetch.fcgi?db=%1$s&id=%2$s&rettype=%3$s&retmode=text",
      method: :rest
    },
    ncbi_map:{
      dbs: { assembly:{map_to: :nuccore, format: :text} },
        # FIXME ncbi_map is intended to do internal NCBI mapping between
        # databases.
      url: "#{@@_EUTILS}elink.fcgi?dbfrom=%1$s&id=%2$s&db=%3$s - - - - -",
      method: :rest,
      map_to_universe: :ncbi
    }
  }

end

