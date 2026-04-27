# frozen_string_literal: true

module ESM
  module Command
    module Test
      class ArgumentDefault < ApplicationCommand
        argument :input, default: "default success!"
      end
    end
  end
end
