# frozen_string_literal: true

module ESM
  class Test
    class << self
      attr_writer :messages
      attr_accessor :skip_cooldown, :territory_admin_uids

      def messages
        @messages ||= Messages.new
      end
    end
  end
end
