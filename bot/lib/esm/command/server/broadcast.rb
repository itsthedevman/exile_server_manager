# frozen_string_literal: true

# New command? Make sure to create a migration to add the configuration to all communities
module ESM
  module Command
    module Server
      class Broadcast < ESM::Command::Base
        type :player
        limit_to :text
        requires :registration

        define :enabled, modifiable: true, default: true
        define :whitelist_enabled, modifiable: true, default: true
        define :whitelisted_role_ids, modifiable: true, default: []
        define :allowed_in_text_channels, modifiable: true, default: true
        define :cooldown_time, modifiable: true, default: 2.seconds

        argument :broadcast_to, regex: ESM::Regex::BROADCAST, description: "commands.broadcast.arguments.broadcast_to"
        argument :message, regex: /(.|[\r\n])+/, description: "commands.broadcast.arguments.message", preserve: true, multiline: true

        def discord
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
          response = ESM.bot.deliver_and_await!(embed, to: current_channel, owner: current_user, expected: [I18n.t("yes"), I18n.t("no")], timeout: 120)
          return reply(I18n.t("commands.broadcast.cancelation_reply")) if response.nil? || response.downcase == I18n.t("no").downcase

          # Get all of the users to broadcast to
          users = load_users
          users.each { |user| ESM.bot.deliver(broadcast_embed(server_ids: @server_id_sentence), to: user.discord_id) }

          # Send the success message back
          reply(ESM::Embed.build(:success, description: I18n.t("commands.broadcast.success_message", user: current_user.mention)))
        end

        def broadcast_embed(server_ids: "server_id")
          ESM::Embed.build do |e|
            e.title = I18n.t("commands.broadcast.broadcast_embed.title", community_name: current_community.community_name, server_ids: server_ids)
            e.description = @arguments.message
            e.color = :orange
            e.footer = I18n.t("commands.broadcast.broadcast_embed.footer")
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

              # Get every user that has used a command for this server, but has explicitly denied custom
              # This code will also inherently find users who have set the preference to true since that creates a cooldown
              ESM::Cooldown.where(server_id: server.id).where.not(user_id: denied_user_ids).map(&:user)
            end

          # Flatten and make sure we are only sending to each user once
          users.flatten.uniq(&:discord_id)
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
