require 'miga/remote_dataset/base'

class MiGA::RemoteDataset
  include MiGA::RemoteDataset::Base

  # Class-level
  class << self
    ##
    # Download data from the +universe+ in the database +db+ with IDs +ids+ and
    # in +format+. If passed, it saves the result in +file+. Additional
    # parameters specific to the download method can be passed using +extra+.
    # Returns String. The +obj+ can also be passed as MiGA::RemoteDataset or
    # MiGA::Dataset.
    def download(universe, db, ids, format, file = nil, extra = [], obj = nil)
      ids = [ids] unless ids.is_a? Array
      getter = @@UNIVERSE[universe][:dbs][db][:getter] || :download
      method = @@UNIVERSE[universe][:method]
      opts = {
        universe: universe,
        db: db,
        ids: ids,
        format: format,
        file: file,
        extra: extra,
        obj: obj
      }
      doc = send("#{getter}_#{method}", opts)
      unless opts[:file].nil?
        ofh = File.open(opts[:file], 'w')
        ofh.print doc.force_encoding('UTF-8')
        ofh.close
      end
      doc
    end

    ##
    # Download data from NCBI Assembly database using the REST method.
    # Supported +opts+ (Hash) include:
    # +obj+ (mandatory): MiGA::RemoteDataset
    # +ids+ (mandatory): String or Array of String
    # +file+: String, passed to download
    # +extra+: Array, passed to download
    # +format+: String, passed to download
    def ncbi_asm_rest(opts)
      url_dir = opts[:obj].ncbi_asm_json_doc['ftppath_genbank']
      url = "#{url_dir}/#{File.basename url_dir}_genomic.fna.gz"
      download(
        :web, :assembly_gz, url,
        opts[:format], opts[:file], opts[:extra], opts[:obj]
      )
    end

    ##
    # Download data from NCBI GenBank (nuccore) database using the REST method.
    # Supported +opts+ (Hash) are the same as #download_rest and #ncbi_asm_rest.
    def ncbi_gb_rest(opts)
      o = download_rest(opts)
      return o unless o.strip.empty?

      MiGA::MiGA.DEBUG 'Empty sequence, attempting download from NCBI assembly'
      opts[:format] = :fasta_gz
      if opts[:file]
        File.unlink(opts[:file]) if File.exist? opts[:file]
        opts[:file] = "#{opts[:file]}.gz"
      end
      ncbi_asm_rest(opts)
    end

    ##
    # Download data using the REST method. Supported +opts+ (Hash) include:
    # +universe+ (mandatory): Symbol
    # +db+ (mandatory): Symbol
    # +ids+ (mandatory): Array of String
    # +format+: String
    # +extra+: Array
    def download_rest(opts)
      u = @@UNIVERSE[opts[:universe]]
      url = sprintf(
        u[:url], opts[:db], opts[:ids].join(','), opts[:format], *opts[:extra]
      )
      url = u[:api_key][url] unless u[:api_key].nil?
      download_url url
    end

    ##
    # Alias of download_rest
    alias download_net download_rest

    ##
    # Download the given +url+ and return the result regardless of response
    # code. Attempts download up to three times before raising Net::ReadTimeout.
    def download_url(url)
      doc = ''
      @timeout_try = 0
      begin
        DEBUG 'GET: ' + url
        open(url, read_timeout: 600) { |f| doc = f.read }
      rescue => e
        @timeout_try += 1
        raise e if @timeout_try >= 3

        retry
      end
      doc
    end

    ##
    # Looks for the entry +id+ in +dbfrom+, and returns the linked
    # identifier in +db+ (or nil).
    def ncbi_map(id, dbfrom, db)
      doc = download(:ncbi_map, dbfrom, id, :json, nil, [db])
      return if doc.empty?

      tree = MiGA::Json.parse(doc, contents: true)
      [:linksets, 0, :linksetdbs, 0, :links, 0].each do |i|
        tree = tree[i]
        break if tree.nil?
      end
      tree
    end
  end
end

module MiGA::RemoteDataset::Download
  ##
  # Download data into +file+
  def download(file)
    self.class.download(
      universe, db, ids, self.class.UNIVERSE[universe][:dbs][db][:format],
      file, [], self
    )
  end
end
