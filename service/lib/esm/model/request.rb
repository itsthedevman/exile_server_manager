# frozen_string_literal: true

module ESM
  class Request < ApplicationRecord
    def respond(accepted)
      @accepted = accepted

      # Build the command
      command = ESM::Command[command_name].new

      # Respond
      command.from_request(self)

      # Remove the request
      destroy
    end
  end
end
