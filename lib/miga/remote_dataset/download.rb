
require 'miga/remote_dataset/base'

class MiGA::RemoteDataset
  include MiGA::RemoteDataset::Base

  # Class-level
  class << self
    ##
    # Download data from the +universe+ in the database +db+ with IDs +ids+ and
    # in +format+. If passed, it saves the result in +file+. Returns String.
    def download(universe, db, ids, format, file=nil)
      ids = [ids] unless ids.is_a? Array
      case @@UNIVERSE[universe][:method]
      when :rest
        doc = download_rest(universe, db, ids, format)
      when :net
        doc = download_net(universe, db, ids, format)
      end
      unless file.nil?
        ofh = File.open(file, "w")
        ofh.print doc
        ofh.close
      end
      doc
    end

    ##
    # Download data using a REST method from the +universe+ in the database +db+
    # with IDs +ids+ and in +format+. Returns the doc as String.
    def download_rest(universe, db, ids, format)
      u = @@UNIVERSE[universe]
      map_to = u[:dbs][db].nil? ? nil : u[:dbs][db][:map_to]
      url = sprintf(u[:url], db, ids.join(","), format, map_to)
      response = RestClient::Request.execute(method: :get, url:url, timeout:600)
      unless response.code == 200
        raise "Unable to reach #{universe} client, error code #{response.code}."
      end
      response.to_s
    end

    ##
    # Download data using a GET request from the +universe+ in the database +db+
    # with IDs +ids+ and in +format+. Returns the doc as String.
    def download_net(universe, db, ids, format)
      u = @@UNIVERSE[universe]
      map_to = u[:dbs][db].nil? ? nil : u[:dbs][db][:map_to]
      url = sprintf(u[:url], db, ids.join(","), format, map_to)
      doc = ""
      @timeout_try = 0
      begin
        open(url) { |f| doc = f.read }
      rescue Net::ReadTimeout
        @timeout_try += 1
        if @timeout_try > 3 ; raise Net::ReadTimeout
        else ; retry
        end
      end
      doc
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
