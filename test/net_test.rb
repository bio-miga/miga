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
    assert_raise { m.remote_connection('ssh://microbial-genomes.org/') }
    c = m.remote_connection(:miga_db)
    assert_equal(Net::FTP, c.class)
    c.close
  end

  def test_download_file_http
    declare_remote_access
    m = MiGA::MiGA
    #o = m.http_request(:get, 'http://uibk.microbial-genomes.org/robots.txt')
    o = m.http_request(:get, 'http://aau.microbial-genomes.org/robots.txt')
    o = o.split(/\n/)
    assert_equal(6, o.count)
    assert_equal('#', o[1])
    assert_equal('User-agent: *', o[2])
  end

  def test_download_file_ftp
    declare_remote_access
    f = tmpfile('t/test.txt')
    d = File.dirname(f)
    assert(!Dir.exist?(d))
    m = MiGA::MiGA
    m.download_file_ftp(:miga_online_ftp, 'api_test.txt', f)
    assert(Dir.exist?(d))
    assert_equal('miga', File.read(f).chomp)
    File.unlink(f)
    m.download_file_ftp(:miga_db, '../api_test.txt', f)
    assert_equal('miga', File.read(f).chomp)
  end

  def test_encoding
    # Test original encoding
    t1 = '()!@*#àøo'
    t2 = "#{t1}"
    assert_equal(t1, t2)
    assert_equal(t1, MiGA::MiGA.normalize_encoding(t2))

    # Test with a different encoding
    t2 = t2.encode('windows-1252')
    assert_equal('Windows-1252', t2.encoding.to_s)
    assert_not_equal(t1, t2)
    assert_equal(t1, MiGA::MiGA.normalize_encoding(t2))

    # Test with a different encoding wrongly declared
    t2.force_encoding('utf-8')
    assert_equal('UTF-8', t2.encoding.to_s)
    assert_not_equal(t1, t2)
    assert_equal(t1, MiGA::MiGA.normalize_encoding(t2))
  end
end
