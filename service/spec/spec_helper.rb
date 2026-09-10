# frozen_string_literal: true

# Shared bootstrap for both runs. It deliberately stops short of the two things they disagree on: the around hook,
# which is built out of the Discord fakes, and ESM.run!, whose feature list differs. Those belong to mock_helper and
# live_helper, and neither can have a say if this file has already done them.
#
# Nothing requires this directly. `.rspec` points at mock_helper, `.rspec-live` at live_helper, and both come
# through here.

# Set to false for indefinite wait_timeout
SPEC_TIMEOUT_SECONDS = 10

# The Arma server this suite answers to, started by `arma/bin/spec_server`. Named here rather than in each spec
# that needs it because two servers run side by side and a spec reaching for the wrong one reports the mix-up as
# whatever it was testing having failed.
ARMA_SPEC_SERVER_ID = "esm_test"

LOG_LEVEL = ENV.fetch("LOG_LEVEL", "error").downcase.to_sym

require_relative "pre_init"
require_relative "spec_config"

RSpec.configure do |config|
  config.before :suite do
    FactoryBot.definition_file_paths = [ESM.root.join("spec", "support", "factories")]
    FactoryBot.find_definitions

    DatabaseCleaner.strategy = :deletion
    DatabaseCleaner[:active_record, db: ESM::ExileAccount].strategy = :deletion
    DatabaseCleaner.clean

    # Cache entries outlive the rows they describe: keys are built from database ids, deletion leaves the sequences
    # alone, and a reloaded schema restarts them, so yesterday's entry can answer for today's unrelated record.
    ESM.cache.clear
  end
end
