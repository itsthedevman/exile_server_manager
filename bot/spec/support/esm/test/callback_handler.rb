# frozen_string_literal: true

module ESM
  class Test
    class CallbackHandler
      include ESM::Callbacks

      register_callbacks :before_connection
    end
  end
end
