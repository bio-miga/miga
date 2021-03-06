# frozen_string_literal: true

require 'test_helper'

class ParallelTest < Test::Unit::TestCase
  include TestHelper

  def test_distribute
    declare_forks

    base = tmpfile('base')
    assert(!File.exist?("#{base}-3"))
    MiGA::Parallel.distribute((0..3), 2) do |o, k, t|
      File.open("#{base}-#{o}", 'w') { |fh| fh.puts t }
    end
    assert(File.exist?("#{base}-3"))
    assert(!File.exist?("#{base}-4"))
    t = (0..3).map { |i| File.read("#{base}-#{i}").chomp.to_i }
    assert_equal([0,0,1,1], t.sort)
  end

  def test_thread_enum
    MiGA::Parallel.thread_enum(%w[a b c d], 3, 1) do |o, k, t|
      assert_equal('b', o)
    end

    n = 0
    MiGA::Parallel.thread_enum(0..19, 4, 0) { n += 1 }
    assert_equal(5, n)
  end
end
