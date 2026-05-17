# frozen_string_literal: true

# The main driver for all of ESM's commands. This class is synomysis with ActiveRecord::Base in that all commands inherit
# from this class and this class gives access to a lot of the core functionality.
module ESM
  module Command
    class Base
      DM_CHANNEL_TYPES = [:dm, :direct_message, :pm, :private_message].freeze
      TEXT_CHANNEL_TYPES = [:text, :text_channel].freeze
      CHANNEL_TYPES = (DM_CHANNEL_TYPES + TEXT_CHANNEL_TYPES).freeze

      include Checks
      include Definition
      include Helpers
      include Lifecycle
      include Migration
      include Permissions
    end
  end
end
