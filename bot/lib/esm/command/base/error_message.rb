# frozen_string_literal: true

module ESM
  module Command
    class Base
      module ErrorMessage
        def self.on_cooldown(user:, time_left:, command_name:)
          ESM::Embed.build do |e|
            e.description = I18n.t("command_errors.on_cooldown", user: user.mention, time_left: time_left, command_name: command_name)
            e.color = :yellow
          end
        end

        def self.target_user_nil(user:)
          ESM::Embed.build do |e|
            e.description = I18n.t("command_errors.target_user_nil", user: user.mention)
            e.color = :red
          end
        end

        def self.not_registered(user:)
          ESM::Embed.build do |e|
            e.description = I18n.t("command_errors.not_registered", user: user.mention)
            e.color = :red
          end
        end

        def self.invalid_server_id(user:, provided_server_id:)
          # Attempt to correct them
          corrections = ESM::Websocket.correct(provided_server_id)

          ESM::Embed.build do |e|
            e.description =
              if corrections.blank?
                I18n.t("command_errors.invalid_server_id", user: user.mention, provided_server_id: provided_server_id)
              else
                corrections = corrections.format(join_with: ", ") { |correction| "`#{correction}`" }
                I18n.t("command_errors.invalid_server_id_with_correction", user: user.mention, provided_server_id: provided_server_id, correction: corrections)
              end

            e.color = :red
          end
        end

        def self.server_not_connected(user:, server_id:)
          ESM::Embed.build do |e|
            e.description = I18n.t("command_errors.server_not_connected", user: user.mention, server_id: server_id)
            e.color = :red
          end
        end

        def self.invalid_community_id(user:, provided_community_id:)
          # Attempt to correct them
          corrections = ESM::Community.correct(provided_community_id)

          ESM::Embed.build do |e|
            e.description =
              if corrections.blank?
                I18n.t("command_errors.invalid_community_id", user: user.mention, provided_community_id: provided_community_id)
              else
                corrections = corrections.format(join_with: ", ") { |correction| "`#{correction}`" }
                I18n.t("command_errors.invalid_community_id_with_correction", user: user.mention, provided_community_id: provided_community_id, correction: corrections)
              end

            e.color = :red
          end
        end

        def self.command_not_enabled(user:, command_name:)
          ESM::Embed.build do |e|
            e.description = I18n.t("command_errors.command_not_enabled", user: user.mention, command_name: command_name)
            e.color = :red
          end
        end

        def self.not_whitelisted(user:, command_name:)
          ESM::Embed.build do |e|
            e.description = I18n.t("command_errors.not_whitelisted", user: user.mention, command_name: command_name)
            e.color = :red
          end
        end

        def self.not_allowed_in_text_channels(user:, command_name:)
          ESM::Embed.build do |e|
            e.description = I18n.t("command_errors.not_allowed_in_text_channels", user: user.mention, command_name: command_name)
            e.color = :red
          end
        end

        def self.player_mode_command_not_available(user:, command_name:)
          ESM::Embed.build do |e|
            e.description = I18n.t("command_errors.player_mode_command_not_available", user: user.mention, command_name: command_name)
            e.color = :red
          end
        end

        def self.different_community_in_text(user:)
          ESM::Embed.build do |e|
            e.description = I18n.t("command_errors.different_community_in_text", user: user.mention)
            e.color = :red
          end
        end

        def self.pending_request(user:)
          ESM::Embed.build(:error, description: I18n.t("command_errors.pending_request", user: user.mention))
        end
      end
    end
  end
end
