# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = "esm_ruby_core"
  spec.version = "2.0.0"
  spec.authors = ["Bryan"]
  spec.email = ["bryan@itsthedevman.com"]

  spec.summary = "esm_ruby_core"
  spec.description = "esm_ruby_core"

  spec.required_ruby_version = ">= 3.1.0"
  spec.require_paths = ["lib"]

  spec.add_dependency "colorize"
  spec.add_dependency "fast_jsonparser"
  spec.add_dependency "http"
  spec.add_dependency "ostruct"

  spec.add_development_dependency "database_cleaner-active_record"
  spec.add_development_dependency "factory_bot"
  spec.add_development_dependency "faker"
  spec.add_development_dependency "pg"
  spec.add_development_dependency "rspec"
end
