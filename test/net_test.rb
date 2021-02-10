require 'test_helper'

class FormatTest < Test::Unit::TestCase
  include TestHelper

  def test_known_hosts
    m = MiGA::MiGA
    assert_not_nil(m.known_hosts(:miga_db))
    assert_not_nil(m.known_hosts('miga_db'))
    assert_not_nil(m.known_hosts(:miga_dist))
    assert_raise { m.known_kosts(:not_a_host) }
  end

  def test_remote_connection
    declare_remote_access
    m = MiGA::MiGA
    assert_raise { m.remote_connection(:bad_descriptor) }
    assert_raise { m.remote_connection('http://microbial-genomes.org/') }
    c = m.remote_connection(:miga_db)
    assert_equal(Net::FTP, c.class)
    c.close
  end

  def test_download_file_ftp
    declare_remote_access
    m = MiGA::MiGA
    f = tmpfile('t/test.txt')
    d = File.dirname(f)
    assert(!Dir.exist?(d))
    m.download_file_ftp(:miga_online_ftp, 'test.txt', f)
    assert(Dir.exist?(d))
    assert_equal('miga', File.read(f).chomp)
  end
end
