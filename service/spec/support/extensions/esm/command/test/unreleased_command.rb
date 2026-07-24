# frozen_string_literal: true

module ESM
  module Command
    module Test
      class UnreleasedCommand < ApplicationCommand
        unreleased!
      end
    end
  end
end
