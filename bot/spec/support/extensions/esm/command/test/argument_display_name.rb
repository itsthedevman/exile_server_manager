# frozen_string_literal: true

module ESM
  module Command
    module Test
      class ArgumentDisplayName < ApplicationCommand
        argument :argument_name, display_name: :display_name
      end
    end
  end
end
