# frozen_string_literal: true

require_relative "lib/typesafe/version"

Gem::Specification.new do |spec|
  spec.name = "typesafe-ai-ruby"
  spec.version = TypeSafe::VERSION
  spec.authors = ["hnegishi"]
  spec.email = ["negishi_h@uuum.jp"]

  spec.summary = "Ruby client for the TypeSafe AI System One API (Jev)"
  spec.description = <<~DESC.strip
    Ask TypeSafe's Jev model typed Noul, Choice, and Score questions about text or
    structured state and get calibrated, structured answers back. Zero runtime dependencies.
  DESC
  spec.homepage = "https://github.com/hnegishi/typesafe-ai-ruby"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata = {
    "source_code_uri" => spec.homepage,
    "changelog_uri" => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "bug_tracker_uri" => "#{spec.homepage}/issues",
    "documentation_uri" => "https://docs.typesafe.ai/",
    "rubygems_mfa_required" => "true"
  }

  # logger leaves the default gems in Ruby 4.0; declare it so the client works under Bundler there.
  spec.add_dependency "logger", "~> 1.5"

  spec.files = Dir["lib/**/*.rb", "sig/**/*.rbs", "README.md", "CHANGELOG.md", "LICENSE.txt"]
  spec.require_paths = ["lib"]
end
