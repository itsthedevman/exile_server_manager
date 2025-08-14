# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = "esm_ruby_core"
  spec.version = "0.0.1"
  spec.authors = ["Bryan"]
  spec.email = ["bryan@itsthedevman.com"]

  spec.summary = "esm_ruby_core"
  spec.description = "esm_ruby_core"

  spec.required_ruby_version = ">= 3.1.0"
  spec.require_paths = ["lib"]

  spec.add_dependency "colorize"
  spec.add_dependency "fast_jsonparser"
  spec.add_dependency "http"
end
