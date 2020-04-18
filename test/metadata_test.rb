require 'test_helper'
require 'miga/metadata'

class MetadataTest < Test::Unit::TestCase

  def setup
    $tmp = Dir.mktmpdir
    $jruby_tests = !ENV['JRUBY_TESTS'].nil?
  end

  def teardown
    FileUtils.rm_rf $tmp
  end

  def test_save
    omit_if($jruby_tests, 'JRuby doesn\'t implement fork.')
    md1 = MiGA::Metadata.new(File.expand_path('md_save.json', $tmp))
    FileUtils.touch(md1.lock_file)
    fork do
      sleep(1)
      File.unlink(md1.lock_file)
    end
    t1 = Time.new
    md1.save
    t2 = Time.new
    assert_path_not_exist(md1.lock_file)
    assert_ge(t2 - t1, 1.0)
  end

  def test_load
    md1 = MiGA::Metadata.new(File.expand_path('md_load.json', $tmp), {t: 1})
    assert_equal(1, md1[:t])
    omit_if($jruby_tests, 'JRuby doesn\'t implement fork.')
    FileUtils.touch(md1.lock_file)
    fork do
      sleep(1)
      File.open(md1.path, 'w') { |fh| fh.print '{"t": 2}' }
      File.unlink(md1.lock_file)
    end
    t1 = Time.new
    md1.load
    t2 = Time.new
    assert_equal(2, md1[:t])
    assert_path_not_exist(md1.lock_file)
    assert_ge(t2 - t1, 1.0)
  end

end
