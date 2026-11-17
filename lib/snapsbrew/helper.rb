module Snapsbrew
  # View helpers that render a snap from a signed URL.
  module Helper
    #   <%= snapsbrew_image_tag template: "044ec825-...", alt: @post.title, title: @post.title %>
    #
    # Each other keyword is a layer of the template. Give HTML attributes with html:.
    def snapsbrew_image_tag(template:, alt:, html: {}, **variants)
      image_tag Snapsbrew.signed_url(template:, **variants), alt:, **html
    end

    #   <%= snapsbrew_og_image_tag template: "044ec825-...", title: @post.title %>
    def snapsbrew_og_image_tag(template:, **variants)
      tag.meta property: "og:image", content: Snapsbrew.signed_url(template:, **variants)
    end
  end
end
