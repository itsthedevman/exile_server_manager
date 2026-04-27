# frozen_string_literal: true

module ESM
  class Xm8Notification
    class MarxetItemSold < Xm8Notification
      def valid?
        content.item_name.present? && content.poptabs_received.present?
      end
    end
  end
end
