require "test_helper"

class Snapsbrew::RecordTest < Snapsbrew::TestCase
  def test_reads_fields_as_methods_and_with_brackets
    record = Snapsbrew::Record.new("title" => "Launch", "layers" => [ { "layer" => "headline" } ], "meta" => { "next" => nil })

    assert_equal "Launch", record.title
    assert_equal "Launch", record[:title]
    assert_equal "headline", record.layers.first.layer
    assert_nil record.meta.next
    assert_respond_to record, :title
  end

  def test_an_unknown_field_raises
    assert_raises(NoMethodError) { Snapsbrew::Record.new({}).title }
    assert_nil Snapsbrew::Record.new({})[:title]
  end

  def test_to_h_and_equality
    assert_equal({ "id" => 1 }, Snapsbrew::Record.new(id: 1).to_h)
    assert_equal Snapsbrew::Record.new(id: 1), Snapsbrew::Record.new("id" => 1)
  end
end
