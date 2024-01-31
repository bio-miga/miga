require 'test_helper'
require 'miga/metadata'

class MetadataTest < Test::Unit::TestCase
  include TestHelper

  def test_save
    declare_forks
    md1 = MiGA::Metadata.new(tmpfile('md_save.json'))
    FileUtils.touch(md1.lock_file)
    fork do
      sleep(1)
      File.unlink(md1.lock_file)
    end
    t1 = Time.new
    md1.save!
    t2 = Time.new
    assert_path_not_exist(md1.lock_file)
    assert_ge(t2 - t1, 1.0)
  end

  def test_load
    md1 = MiGA::Metadata.new(tmpfile('md_load.json'), { t: 1 })
    assert_equal(1, md1[:t])

    declare_forks
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
