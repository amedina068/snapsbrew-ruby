require_relative "lib/snapsbrew/version"

Gem::Specification.new do |spec|
  spec.name        = "snapsbrew"
  spec.version     = Snapsbrew::VERSION
  spec.authors     = [ "Alejandro Medina" ]
  spec.summary     = "Ruby client and Rails integration for the Snapsbrew image API"
  spec.description = "Render snaps from Snapsbrew templates, build signed image URLs, " \
                     "and show them in Rails views. The gem uses the Ruby standard library only."
  spec.homepage    = "https://github.com/amedina068/snapsbrew-ruby"
  spec.license     = "MIT"

  spec.required_ruby_version = ">= 3.2"

  spec.metadata = {
    "source_code_uri" => spec.homepage,
    "changelog_uri" => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir["lib/**/*", "sig/**/*", "README.md", "CHANGELOG.md", "LICENSE"]
  spec.require_paths = [ "lib" ]
end
