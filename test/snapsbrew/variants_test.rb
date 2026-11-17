require "test_helper"

class Snapsbrew::VariantsTest < Snapsbrew::TestCase
  def test_a_string_is_text
    assert_equal [ { layer: "title", text: "Hello" } ], normalize(title: "Hello")
  end

  def test_a_number_is_text
    assert_equal [ { layer: "price", text: "40" } ], normalize(price: 40)
  end

  def test_an_http_url_is_an_image
    assert_equal [ { layer: "cover", image_url: "https://example.com/a.jpg" } ], normalize(cover: "https://example.com/a.jpg")
    assert_equal [ { layer: "cover", image_url: "http://example.com/a.jpg" } ], normalize(cover: URI("http://example.com/a.jpg"))
  end

  def test_false_or_nil_hides_the_layer
    assert_equal [ { layer: "badge", hidden: true }, { layer: "logo", hidden: true } ], normalize(badge: false, logo: nil)
  end

  def test_a_hash_names_the_override
    assert_equal [ { layer: "bg", background_color: "#f0573f" }, { layer: "footer", text: "https://snapsbrew.com" } ],
      normalize(bg: { background_color: "#f0573f" }, footer: { text: "https://snapsbrew.com" })
  end

  def test_an_array_passes_through
    variants = [ { "layer" => "title", "text" => "Hello" } ]

    assert_same variants, normalize(variants)
  end

  def test_nil_stays_nil
    assert_nil normalize(nil)
  end

  def test_another_type_is_an_error
    assert_raises(ArgumentError) { normalize("title=Hello") }
  end

  private
    def normalize(variants) = Snapsbrew::Variants.normalize(variants)
end
