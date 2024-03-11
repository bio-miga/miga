require 'miga/remote_dataset/base'

class MiGA::RemoteDataset
  include MiGA::RemoteDataset::Base

  # Class-level
  class << self
    ##
    # Return hash of options used internally for the getter methods, including
    # by +download+. The prepared request is for data from the +universe+ in the
    # database +db+ with IDs +ids+ and in +format+. If passed, it saves the
    # result in +file+. Additional parameters specific to the download method
    # can be passed using +extra+. The +obj+ can also be passed as
    # MiGA::RemoteDataset or MiGA::Dataset
    def download_opts(
          universe, db, ids, format, file = nil, extra = {}, obj = nil)
      universe_hash = @@UNIVERSE[universe]
      database_hash = universe_hash.dig(:dbs, db)
      getter = database_hash[:getter] || :download
      action = database_hash[:method] || universe_hash[:method]

      # Clean IDs
      ids = 

      # Return options
      {
        universe: universe,  db:   db,    ids: ids.is_a?(Array) ? ids : [ids],
        format:   format,    file: file,  obj: obj,
        extra:    (database_hash[:extra] || {}).merge(extra),
        _fun:     :"#{getter}_#{action}"
      }
    end

    ##
    # Returns String. The prequired parameters (+params+) are identical to those
    # of +download_opts+ (see for details)
    def download(*params)
      opts = download_opts(*params)
      doc = send(opts[:_fun], opts)

      unless opts[:file].nil?
        ofh = File.open(opts[:file], 'w')
        unless opts[:file] =~ /\.([gb]?z|tar|zip|rar)$/i
          doc = normalize_encoding(doc)
        end
        ofh.print doc
        ofh.close
      end
      doc
    end

    ##
    # Download data from NCBI Assembly database using the REST method.
    # Supported +opts+ (Hash) include:
    # +obj+ (mandatory): MiGA::RemoteDataset
    # +ids+ (mandatory): String or Array of String
    # +file+ (mandatory): String, assembly saved here
    # +extra+: Hash, passed to download
    # +format+: String, ignored
    def ncbi_asm_get(opts)
      require 'tempfile'
      require 'zip'

      zipped = download(
        :ncbi_datasets_download, :genome, opts[:ids],
        :zip, nil, opts[:extra], opts[:obj]
      )
      zip_tmp = Tempfile.new(['asm', '.zip'], encoding: zipped.encoding.to_s)
      zip_tmp.print(zipped)
      zip_tmp.close

      o = ''
      ofh = opts[:file] ? File.open(opts[:file], 'w') : nil
      Zip::File.open(zip_tmp.path) do |zfh|
        zfh.each do |entry|
          if entry.file? && entry.name =~ /_genomic\.fna$/
            DEBUG "Extracting: #{entry.name}"
            entry.get_input_stream do |ifh|
              cont = MiGA::MiGA.normalize_encoding(ifh.read).chomp + "\n"
              ofh&.print(cont)
              o += cont
            end
          end
        end
      end
      ofh&.close
      File.unlink(zip_tmp.path)
      o
    end

    ##
    # Download data from NCBI GenBank (nuccore) database using the REST method.
    # Supported +opts+ (Hash) are the same as #download_rest and #ncbi_asm_get.
    def ncbi_gb_get(opts)
      # Simply use defaults, but ensure that the URL can be properly formed
      o = download_rest(opts.merge(universe: :ncbi, db: :nuccore))
      return o unless o.strip.empty?

      begin
        MiGA::MiGA.DEBUG 'Empty sequence, attempting download as NCBI assembly'
        opts[:format] = :fasta
        ncbi_asm_get(opts)
      rescue => e
        raise e unless opts[:obj]&.metadata&.dig(:ncbi_wgs)
        MiGA::MiGA.DEBUG e.to_s
      end

      MiGA::MiGA.DEBUG 'Empty sequence, attempting download as WGS records'
      a, b = opts[:obj].metadata[:ncbi_wgs].split('-', 2)
      pref = longest_common_prefix([a, b])
      rang = a[pref.size .. -1].to_i .. b[pref.size .. -1].to_i
      ids  = rang.map { |k| "%s%0#{a.size - pref.size}i" % [pref, k] }
      download_rest(opts.merge(universe: :ncbi, db: :nuccore, ids: ids))
    end

    ##
    # Download data using the GET method. Supported +opts+ (Hash) include:
    # +universe+ (mandatory): Symbol
    # +db+: Symbol
    # +ids+: Array of String
    # +format+: String
    # +extra+: Hash
    def download_get(opts)
      u = @@UNIVERSE[opts[:universe]]
      download_uri(u[:uri][opts], u[:headers] ? u[:headers][opts] : {})
    end

    ##
    # Download data using the POST method. Supported +opts+ (Hash) include:
    # +universe+ (mandatory): Symbol
    # +db+: Symbol
    # +ids+: Array of String
    # +format+: String
    # +extra+: Hash
    def download_post(opts)
      u = @@UNIVERSE[opts[:universe]]
      uri = u[:uri][opts]
      payload = u[:payload] ? u[:payload][opts] : ''
      headers = u[:headers] ? u[:headers][opts] : {}
      net_method(:post, uri, payload, headers)
    end

    ##
    # Download data using the FTP protocol. Supported +opts+ (Hash) include:
    # +universe+ (mandatory): Symbol
    # +db+: Symbol
    # +ids+: Array of String
    # +format+: String
    # +extra+: Hash
    def download_ftp(opts)
      u = @@UNIVERSE[opts[:universe]]
      net_method(:ftp, u[:uri][opts])
    end

    ##
    # Redirects to +download_get+ or +download_ftp+, depending on the URI's
    # protocol
    def download_net(opts)
      u = @@UNIVERSE[opts[:universe]]
      if u[:scheme][opts] == 'ftp'
        download_ftp(opts)
      else
        download_get(opts)
      end
    end

    ##
    # Alias of download_rest
    alias download_rest download_get

    ##
    # Download the given +URI+ and return the result regardless of response
    # code. Attempts download up to three times before raising Net::ReadTimeout.
    def download_uri(uri, headers = {})
      net_method(:get, uri, headers)
    end

    ##
    # Download the given +url+ and return the result regardless of response
    # code. Attempts download up to three times before raising Net::ReadTimeout.
    def download_url(url, headers = {})
      download_uri(URI.parse(url), headers)
    end

    ##
    # Looks for the entry +id+ in +dbfrom+, and returns the linked
    # identifier in +db+ (or nil).
    def ncbi_map(id, dbfrom, db)
      attempts = 0
      doc = download(:ncbi_map, dbfrom, id, :json, nil, db: db)
      return if doc.empty?

      begin
        tree = MiGA::Json.parse(doc, contents: true)
      rescue => e
        sleep 5 # <- Usually caused by busy servers: BLOB ID IS NOT IMPLEMENTED
        DEBUG "RETRYING after: #{e}"
        doc = download(:ncbi_map, dbfrom, id, :json, nil, db: db)
        return if doc.empty?
        tree = MiGA::Json.parse(doc, contents: true)
      end

      tree&.dig(:linksets, 0, :linksetdbs, 0, :links, 0)
    end

    ##
    # From: https://github.com/isisAnchalee/Algorithms
    def longest_common_prefix(strs)
      return '' if strs.empty?
      min, max = strs.minmax
      idx = min.size.times { |i| break i if min[i] != max[i] }
      min[0...idx]
    end
  end
end

module MiGA::RemoteDataset::Download
  ##
  # Download data into +file+
  def download(file)
    self.class.download(*download_params(file))
  end

  def universe_hash
    self.class.UNIVERSE[universe]
  end

  def database_hash
    universe_hash.dig(:dbs, db)
  end

  def download_params(file = nil)
    [universe, db, ids, database_hash[:format], file, {}, self]
  end

  def download_opts(file = nil)
    self.class.download_opts(*download_params(file))
  end

  def download_uri
    universe_hash[:uri][download_opts]
  end

  def download_headers
    universe_hash[:headers][download_opts]
  end

  def download_payload
    universe_hash[:payload][download_opts]
  end
end
