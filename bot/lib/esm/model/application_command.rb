# frozen_string_literal: true

module ESM
  class ApplicationCommand < ESM::Command::Base
    self.abstract_class = true

    # Require registration by default
    requires :registration
  end
end
