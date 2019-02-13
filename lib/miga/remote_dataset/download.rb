
require 'miga/remote_dataset/base'

class MiGA::RemoteDataset
  include MiGA::RemoteDataset::Base

  # Class-level
  class << self
    ##
    # Download data from the +universe+ in the database +db+ with IDs +ids+ and
    # in +format+. If passed, it saves the result in +file+. Additional
    # parameters specific to the download method can be passed using +extra+.
    # Returns String.
    def download(universe, db, ids, format, file = nil, extra = [])
      ids = [ids] unless ids.is_a? Array
      case @@UNIVERSE[universe][:method]
      when :rest
        doc = download_rest(universe, db, ids, format, extra)
      when :net
        doc = download_net(universe, db, ids, format, extra)
      end
      unless file.nil?
        ofh = File.open(file, 'w')
        ofh.print doc
        ofh.close
      end
      doc
    end

    ##
    # Download data using a REST method from the +universe+ in the database +db+
    # with IDs +ids+ and in +format+. Additional URL parameters can be passed
    # using +extra+. Returns the doc as String.
    def download_rest(universe, db, ids, format, extra = [])
      u = @@UNIVERSE[universe]
      url = sprintf(u[:url], db, ids.join(","), format, *extra)
      url = u[:api_key][url] unless u[:api_key].nil?
      download_url url
    end

    ##
    # Download data using a GET request from the +universe+ in the database +db+
    # with IDs +ids+ and in +format+. Additional URL parameters can be passed
    # using +extra+. Returns the doc as String.
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
      tree = JSON.parse(doc, symbolize_names: true)
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
  # Download data into +file+.
  def download(file)
    self.class.download(universe, db, ids,
          self.class.UNIVERSE[universe][:dbs][db][:format], file)
  end
end
