# frozen_string_literal: true

ESM.loader.tap do |loader|
  loader.inflector.inflect(
    "esm" => "ESM",
    "ostruct" => "OpenStruct",
    "xm8" => "XM8",
    "api" => "API",
    "json" => "JSON"
  )

  # Convert ESM::Model::Server -> ESM::Server
  loader.collapse(ESM.root.join("lib", "esm", "model"))

  # Forces the jobs to be loaded on the Root path
  # ESM::Jobs::SomeJob -> SomeJob
  loader.push_dir(ESM.root.join("lib", "esm", "jobs"))

  # I very must dislike this.
  loader.ignore(ESM.root.join("lib", "esm", "command", "base.rb"))
  loader.ignore(ESM.root.join("lib", "esm", "command", "base"))
  loader.ignore(ESM.root.join("lib", "esm", "database.rb"))
  loader.ignore(ESM.root.join("lib", "esm", "discord", "extension"))
  loader.ignore(ESM.root.join("lib", "esm", "esm.rb"))
  loader.ignore(ESM.root.join("lib", "esm", "extension"))
  loader.ignore(ESM.root.join("lib", "esm", "model", "application_command.rb"))
  loader.ignore(ESM.root.join("lib", "esm", "model", "application_record.rb"))
  loader.ignore(ESM.root.join("lib", "esm", "model", "community.rb"))
  loader.ignore(ESM.root.join("lib", "esm", "model", "notification.rb"))
  loader.ignore(ESM.root.join("lib", "esm", "model", "request.rb"))
  loader.ignore(ESM.root.join("lib", "esm", "model", "server_reward.rb"))
  loader.ignore(ESM.root.join("lib", "esm", "model", "server.rb"))
  loader.ignore(ESM.root.join("lib", "esm", "model", "user.rb"))
  loader.ignore(ESM.root.join("lib", "esm", "version.rb"))
  loader.ignore(ESM.root.join("lib", "post_init"))
  loader.ignore(ESM.root.join("lib", "pre_init"))
end
