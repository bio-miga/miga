require 'test_helper'

class JsonTest < Test::Unit::TestCase

  def test_parse
    assert_equal(
      { a: 1, b: 2 },
      MiGA::Json.parse('{"a": 1, "b": 2}', contents: true)
    )
    assert_equal(
      { 'a' => 1, 'b' => 2 },
      MiGA::Json.parse('{"a": 1, "b": 2}', contents: true, symbolize: false)
    )
    assert_equal(1.0, MiGA::Json.parse('1.0', contents: true))
  end

  def test_defaults
    tmp1 = Tempfile.new('test-parse-1.json')
    tmp1.puts '{"a": 123, "k": false, "t": null}'
    tmp1.close
    assert_equal({a: 123, k: false, t: nil}, MiGA::Json.parse(tmp1.path))

    tmp2 = Tempfile.new('test-parse-2.json')
    tmp2.puts '{"a": 456, "kb": false, "t": 10.0}'
    tmp2.close
    assert_equal({a: 456, kb: false, t: 10.0}, MiGA::Json.parse(tmp2.path))

    assert_equal(
      {a: 123, k: false, kb: false, t: nil},
      MiGA::Json.parse(tmp1.path, default: tmp2.path)
    )
    assert_equal(
      {a: 456, k: false, kb: false, t: 10.0},
      MiGA::Json.parse(tmp2.path, default: tmp1.path)
    )
  end

  def test_generate
    assert_equal("{\n  \"a\": 1,\n  \"b\": 2\n}",
      MiGA::Json.generate({a: 1, b: 2})
    )
  end

end
