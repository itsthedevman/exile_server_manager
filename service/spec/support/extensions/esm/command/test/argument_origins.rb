# frozen_string_literal: true

module ESM
  module Command
    module Test
      class ArgumentOrigins < ApplicationCommand
        argument :shared, description: "Available to every origin"
        argument :website_only, description: "Available to the website only", origins: [:website]
      end
    end
  end
end
