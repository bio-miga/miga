require 'cgi'

class MiGA::RemoteDataset < MiGA::MiGA
  # Class-level
  class << self
    def UNIVERSE
      @@UNIVERSE
    end
  end
end

def uri_safe_join(*parts)
  safe = parts.map { |i| i.is_a?(Array) ? i.join(',') : i.to_s }
  last = safe.pop
  safe.map! { |i| i[-1] == '/' ? i : "#{i}/" }
  safe << last
  URI::join(*safe)
end

module MiGA::RemoteDataset::Base
  @@_NCBI_DATASETS = 'https://api.ncbi.nlm.nih.gov/datasets/v2alpha/'
  @@_EUTILS        = 'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/'
  @@_EBI_API       = 'https://www.ebi.ac.uk/Tools/'
  @@_GTDB_API      = 'https://gtdb-api.ecogenomic.org/'
  @@_SEQCODE_API   = 'https://disc-genomics.uibk.ac.at/seqcode/'
  @@_EUTILS_BUILD  = lambda { |service, q|
    q[:api_key] = ENV['NCBI_API_KEY'] if ENV['NCBI_API_KEY']
    uri_safe_join(@@_EUTILS, "#{service}.fcgi")
      .tap { |uri| uri.query = URI.encode_www_form(q) }
  }

  ##
  # Structure of the different database Universes or containers. The structure
  # is a Hash with universe names as keys as Symbol and values being a Hash with
  # supported keys as Symbol:
  # - +:dbs+ => Hash with keys being the database name and the values a Hash of
  #   properties such as +stage+, +format+, +map_to+, and +getter+.
  # - +uri+ => Function producing a parsed URI object, accepting one parameter:
  #   a Hash of options.
  # - +method+ => Method used to query the URL. Only +:rest+ and +:net+ are
  #   currently supported.
  # - +map_to_universe+ => Universe where results map to. Currently unsupported.
  # - +scheme+ => Function returning the scheme used as a String (ftp, http,
  #   https). Mandatory if method is :net.
  @@UNIVERSE = {
    web: {
      dbs: {
        assembly: { stage: :assembly, format: :fasta },
        assembly_gz: { stage: :assembly, format: :fasta_gz },
        text: { stage: :metadata, format: :text }
      },
      uri: lambda { |opts| URI.parse(opts[:ids][0]) },
      scheme: lambda { |opts| opts[:ids][0].split(':', 2)[0] },
      method: :net
    },
    ebi: {
      dbs: { embl: { stage: :assembly, format: :fasta } },
      uri: lambda do |opts|
        uri_safe_join(
          @@_EBI_API, 'dbfetch', 'dbfetch', opts[:db], opts[:ids], opts[:format]
        )
      end,
      method: :get
    },
    gtdb: {
      dbs: {
        # This is a dummy entry plugged directly to +ncbi_asm_get+
        assembly: { stage: :assembly, format: :fasta, getter: :ncbi_asm },
        # The 'taxon' namespace actually returns a list of genomes (+format+)
        taxon: {
          stage: :metadata, format: :genomes, map_to: [:assembly],
          extra: { sp_reps_only: false }
        },
        # The 'genome' namespace actually returns the taxonomy (+format+)
        genome: { stage: :metadata, format: 'taxon-history' }
      },
      uri: lambda do |opts|
        uri_safe_join(@@_GTDB_API, opts[:db], opts[:ids], opts[:format])
          .tap { |uri| uri.query = URI.encode_www_form(opts[:extra]) }
      end,
      method: :get,
      map_to_universe: :ncbi,
      headers: lambda { |_opts| { 'Accept' => 'application/json' } }
    },
    seqcode: {
      dbs: {
        # These are dummy entries plugged directly to +ncbi_*_get+
        assembly: { stage: :assembly, format: :fasta, getter: :ncbi_asm },
        nuccore:  { stage: :assembly, format: :fasta, getter: :ncbi_gb },
        # This is the list of type genomes
        :'type-genomes' => { stage: :metadata, format: :json }
      },
      uri: lambda do |opts|
        uri_safe_join(@@_SEQCODE_API, "#{opts[:db]}.json")
          .tap { |uri| uri.query = URI.encode_www_form(opts[:extra]) }
      end,
      method: :get,
      map_to_universe: :ncbi
    },
    ncbi: {
      dbs: {
        nuccore: { stage: :assembly, format: :fasta, getter: :ncbi_gb },
        assembly: { stage: :assembly, format: :fasta, getter: :ncbi_asm },
        taxonomy: { stage: :metadata, format: :xml }
      },
      uri: lambda do |opts|
        @@_EUTILS_BUILD[:efetch,
          db: opts[:db], id: opts[:ids], rettype: opts[:format], retmode: :text
        ]
      end,
      method: :get
    },
    ncbi_map: {
      dbs: {
        nuccore: {
          stage: :metadata, map_to: [:biosample, :assembly], format: :json
        },
        biosample: { stage: :metadata, map_to: [:assembly], format: :json }
      },
      uri: lambda do |opts|
        @@_EUTILS_BUILD[:elink, {
          dbfrom: opts[:db], id: opts[:ids], retmode: opts[:format]
        }.merge(opts[:extra])]
      end,
      method: :get,
      map_to_universe: :ncbi
    },
    ncbi_summary: {
      dbs: { assembly: { stage: :metadata, format: :json } },
      uri: lambda do |opts|
        @@_EUTILS_BUILD[:esummary,
          db: opts[:db], id: opts[:ids], retmode: opts[:format]
        ]
      end,
      method: :get
    },
    ncbi_search: {
      dbs: {
        assembly: { stage: :metadata, format: :json },
        taxonomy: { stage: :metadata, format: :json }
      },
      uri: lambda do |opts|
        @@_EUTILS_BUILD[:esearch,
          db: opts[:db], term: opts[:ids], retmode: opts[:format]
        ]
      end,
      method: :get
    },
    ncbi_datasets_download: {
      dbs: { genome: { stage: :assembly, format: :zip } },
      uri: lambda do |opts|
        q = { include_annotation_type: 'GENOME_FASTA' }
        uri_safe_join(
          @@_NCBI_DATASETS, opts[:db], :accession, opts[:ids], :download
        ).tap { |uri| uri.query = URI.encode_www_form(q) }
      end,
      method: :get,
      headers: lambda do |opts|
        {}.tap do |h|
          h['Accept'] = 'application/zip' if opts[:format] == :zip
          h['api-key'] = ENV['NCBI_API_KEY'] if ENV['NCBI_API_KEY']
        end
      end
    },
    ncbi_datasets: {
      dbs: {
        genome: {
          stage: :metadata, format: :json, extra: { action: 'dataset_report' }
        }
      },
      uri: lambda do |opts|
        uri_safe_join(@@_NCBI_DATASETS, opts[:db], opts[:extra][:action])
      end,
      payload: lambda do |opts|
        query = opts[:ids][0]
        q = {
          filters: {
            assembly_version: 'current',
            exclude_paired_reports: true
          }.merge(query[:filters] || {}),
          page_size: query[:page_size] || 1_000,
          returned_content: 'COMPLETE'
        }
        q[:page_token] = query[:page_token] if query[:page_token]
        q[:taxons] = query[:taxons] if query[:taxons]
        MiGA::Json.generate_plain(q)
      end,
      headers: lambda do |opts|
        {}.tap do |h|
          h['api-key'] = ENV['NCBI_API_KEY'] if ENV['NCBI_API_KEY']
          h['Content-Type'] = 'application/json' if opts[:format] == :json
        end
      end,
      method: :post
    }
  }
end
