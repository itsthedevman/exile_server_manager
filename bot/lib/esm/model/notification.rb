# frozen_string_literal: true

module ESM
  class Notification < ApplicationRecord
    def build_embed(**templates)
      ESM::Embed.build do |e|
        e.title = format(notification_title, templates) if notification_title.present?
        e.description = format(notification_description, templates) if notification_description.present?

        e.color =
          if notification_color == "random"
            ESM::Color.random
          else
            notification_color
          end
      end
    end

    private

    # Replaces template keys with their values
    def format(string, templates)
      templates.each do |key, value|
        string = string.gsub(/{{\s*#{key}\s*}}/i, value.to_s)
      end

      string
    end
  end
end
