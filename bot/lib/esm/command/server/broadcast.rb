# frozen_string_literal: true

# New command? Make sure to create a migration to add the configuration to all communities
module ESM
  module Command
    module Server
      class Broadcast < ESM::Command::Base
        set_type :admin
        limit_to :text
        requires :registration

        define :enabled, modifiable: true, default: true
        define :whitelist_enabled, modifiable: true, default: true
        define :whitelisted_role_ids, modifiable: true, default: []
        define :allowed_in_text_channels, modifiable: true, default: true
        define :cooldown_time, modifiable: true, default: 2.seconds

        argument(
          :broadcast_to,
          regex: ESM::Regex::BROADCAST,
          description: "commands.broadcast.arguments.broadcast_to",
          modifier: lambda do |argument|
            return if argument.content.blank?
            return if %w[all preview].include?(argument.content)

            # If we start with a community ID, just accept the match
            return if argument.content.match("^#{ESM::Regex::COMMUNITY_ID_OPTIONAL.source}_")

            # Add the community ID to the front of the match
            argument.content = "#{current_community.community_id}_#{argument.content}"
          end
        )

        argument :message, regex: /(.|[\r\n])+/, description: "commands.broadcast.arguments.message", preserve: true, multiline: true

        def on_execute
          check_for_message_length!

          # Send just the preview
          return reply(broadcast_embed) if @arguments.broadcast_to == "preview"

          # Preload the servers
          load_servers

          # Send a preview of the embed
          reply(broadcast_embed(server_ids: @server_id_sentence))
          reply("`------------------------------------------------------------------`")
          embed =
            ESM::Embed.build do |e|
              e.title = I18n.t("commands.broadcast.confirmation_embed.title")
              e.description = I18n.t("commands.broadcast.confirmation_embed.description", server_ids: @server_id_sentence)

              e.add_field(name: I18n.t("commands.broadcast.confirmation_embed.field_name"), value: I18n.t("commands.broadcast.confirmation_embed.field_value"))
            end

          # Send the confirmation request
          reply(embed)
          response = ESM.bot.await_response(current_user, expected: [I18n.t("yes"), I18n.t("no")], timeout: 120)
          return reply(I18n.t("commands.broadcast.cancelation_reply")) if response.nil? || response.downcase == I18n.t("no").downcase

          # Get all of the users to broadcast to
          users = load_users
          users.each { |user| ESM.bot.deliver(broadcast_embed(server_ids: @server_id_sentence), to: user.discord_id) }

          # Send the success message back
          reply(ESM::Embed.build(:success, description: I18n.t("commands.broadcast.success_message", user: current_user.mention)))
        end

        def broadcast_embed(server_ids: nil)
          # For the preview
          if server_ids.blank?
            server = current_community.servers.first
            server_ids = server&.server_id || "<server_id_here>"
          end

          ESM::Embed.build do |e|
            e.title = I18n.t("commands.broadcast.broadcast_embed.title", community_name: current_community.community_name, server_ids: server_ids)
            e.description = @arguments.message
            e.color = :orange
            e.footer = I18n.t("commands.broadcast.broadcast_embed.footer", prefix: prefix)
          end
        end

        def load_servers
          @servers =
            if @arguments.broadcast_to == "all"
              current_community.servers
            else
              # Find the server, but check existence and if the server belongs to this community
              server = ESM::Server.find_by_server_id(@arguments.broadcast_to)

              raise_invalid_server_id! if server.nil?
              raise_no_server_access! if server.community_id != current_community.id

              [server]
            end

          # For the broadcast message
          @server_id_sentence = @servers.map { |server| "`#{server.server_id}`" }.to_sentence
        end

        def load_users
          users =
            @servers.map do |server|
              denied_user_ids = ESM::UserNotificationPreference.where(server_id: server.id, custom: false).pluck(:user_id)
              denied_steam_uids = ESM::User.where(id: denied_user_ids).pluck(:steam_uid).reject(&:nil?)

              # Get every user that has used a command for this server, but has not explicitly denied custom
              # This code will also inherently find users who have set the preference to true since that creates a cooldown
              # This query is complex to avoid querying and loading a lot of data.
              user_data = ESM::Cooldown
                .where(server_id: server.id)
                .where.not(user_id: denied_user_ids, steam_uid: denied_steam_uids)
                .uniq { |cooldown| [cooldown.user_id, cooldown.steam_uid] }
                .map { |cooldown| [cooldown.user_id, cooldown.steam_uid] }

              user_ids = user_data.map(&:first).reject(&:nil?).uniq
              steam_uids = user_data.map(&:second).reject(&:nil?).uniq

              ESM::User.where(id: user_ids).or(ESM::User.where(steam_uid: steam_uids))
            end

          # Flatten and make sure we are only sending to each user once
          users.flatten.reject(&:nil?).uniq(&:discord_id)
        end

        def check_for_message_length!
          check_failed!(:message_length, user: current_user.mention) if @arguments.message.size > 2000
        end

        def raise_no_server_access!
          check_failed!(:no_server_access, user: current_user.mention, community_id: current_community.community_id)
        end

        def raise_invalid_server_id!
          check_failed!(:invalid_server_id, user: current_user.mention, provided_server_id: @arguments.broadcast_to)
        end
      end
    end
  end
end
