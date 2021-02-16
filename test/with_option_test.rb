# frozen_string_literal: true

require 'test_helper'
require 'miga/common/with_option'

class WithDaemonTest < Test::Unit::TestCase
  include TestHelper

  class TestWithOption < MiGA::MiGA
    include MiGA::Common::WithOption

    attr_reader :metadata, :saved

    def initialize
      @metadata = { range: 0.9 }
      @saved = false
    end

    def self.OPTIONS
      {
        empty: {},
        float: { type: Float },
        range: { default: 1.0, in: -5.5..5.5, type: Float },
        default: { default: 9, type: Integer },
        token: { type: Integer, tokens: %w[yes no 0] },
        proc: { default: proc { Date.today } },
        bool: { in: [true, false] }
      }
    end

    def save
      @saved = true
    end
  end

  def test_with_option
    o = TestWithOption.new
    assert_respond_to(o, :option)
    assert_equal(1, o.metadata.size)
  end

  def test_option
    o = TestWithOption.new
    assert_equal(9, o.option(:default))
    assert_nil(o.option(:bool))
    assert_raise { o.option(:not_an_option) }
    assert_nil(o.option(:empty))
  end

  def test_set_bool
    o = TestWithOption.new
    assert_nil(o.option(:bool))
    assert(!o.saved)
    assert_raise { o.set_option(:bool, 'true') }
    assert_nil(o.option(:bool))
    assert(!o.saved)
    assert_equal(true, o.set_option(:bool, 'true', true))
    assert(o.saved)
    assert_equal(false, o.set_option(:bool, false))
    assert_equal(false, o.set_option(:bool, 'false', true))
    assert_nil(o.set_option(:bool, nil))
  end

  def test_set_empty
    o = TestWithOption.new
    assert_nil(o.option(:empty))
    assert_equal('a', o.set_option(:empty, 'a'))
    assert_equal('1', o.set_option(:empty, '1', true))
  end

  def test_all_options
    o = TestWithOption.new
    assert(o.all_options.is_a?(Hash))
    assert_include(o.all_options.keys, :bool)
    assert_nil(o.all_options[:bool])
  end

  def test_option?
    o = TestWithOption.new
    assert(o.option?(:range))
    assert(!o.option?(:not_an_option))
  end

  def test_option_metadata
    o = TestWithOption.new
    assert_equal(0.9, o.option(:range))
    assert_equal(1.0, o.set_option(:range, nil))
    assert_equal(2.0, o.set_option(:range, 2.0))
    assert_equal(3.0, o.set_option(:range, '3', true))
  end

  def test_option_range
    o = TestWithOption.new
    assert_raise { o.set_option(:range, 9.0) }
    assert_raise { o.set_option(:range, 3) }
    assert_raise { o.set_option(:range, true) }
  end

  def test_option_proc
    o = TestWithOption.new
    assert(o.option(:proc).is_a?(Date))
    assert(o.set_option(:proc, 1).is_a?(Integer))
    assert(o.set_option(:proc, nil).is_a?(Date))
  end

  def test_token
    o = TestWithOption.new
    assert_nil(o.option(:token))
    assert_equal(1, o.set_option(:token, 1))
    assert_equal(-2, o.set_option(:token, '-2', true))
    assert_equal('yes', o.set_option(:token, 'yes'))
    assert_equal('0', o.set_option(:token, '0', true))
    assert_raise { o.set_option(:token, 'maybe') }
  end
end
