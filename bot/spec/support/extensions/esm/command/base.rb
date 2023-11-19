# frozen_string_literal: true

module ESM
  module Command
    class Base
      attr_writer :limit_to, :requires, :event

      def self.argument(name, type = nil, **opts)
        # This removes the need to provide a description for test commands
        if module_parent.to_s.demodulize == "Test"
          opts[:description] = "Defaulted testing description"
        end

        super(name, type, **opts)
      end
    end
  end
end
