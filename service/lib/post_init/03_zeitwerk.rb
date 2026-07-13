# frozen_string_literal: true

#
# Configures (but does not yet activate) the Zeitwerk autoloader. The
# actual `loader.setup` + `loader.eager_load` happens later in {ESM.load!},
# which {ESM.run!} triggers at boot. Tests skip autoload setup entirely.
#
# What's configured here:
#
#   * Inflector overrides for non-standard casing (ESM, XM8, API, JSON).
#   * `collapse` so `lib/esm/model/server.rb` defines `ESM::Server` rather
#     than `ESM::Model::Server`.
#   * `push_dir` for jobs so they're loaded at the root namespace
#     (`SomeJob` rather than `ESM::Jobs::SomeJob`).
#   * `ignore` for everything loaded manually elsewhere (via Loader) or
#     reopened by extensions, plus the `pre_init/` and `post_init/`
#     directories themselves (they're scripts, not class definitions, and
#     would confuse Zeitwerk's file = constant rule).
#

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

  # Files and directories already loaded manually (or reopened, in the case
  # of extensions). The autoloader would either double-load or raise without
  # these exclusions. Anything in core/lib lives outside this Zeitwerk root
  # already, so it doesn't need ignoring here. The explicit list below is
  # only for files still inside service/lib.
  loader.ignore(ESM.root.join("lib", "esm", "discord", "extension"))
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
