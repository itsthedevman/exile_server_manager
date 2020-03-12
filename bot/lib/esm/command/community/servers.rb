# frozen_string_literal: true

module ESM
  module Command
    module Community
      class Servers < ESM::Command::Base
        type :player

        define :enabled, modifiable: true, default: true
        define :whitelist_enabled, modifiable: true, default: false
        define :whitelisted_role_ids, modifiable: true, default: []
        define :allowed_in_text_channels, modifiable: true, default: true
        define :cooldown_time, modifiable: true, default: 2.seconds

        argument :community_id

        def discord
          servers = ESM::Server.where(community_id: target_community.id)
          raise ESM::Exception::CheckFailure, error_message(:no_servers, community_id: @arguments.community_id) if servers.blank?

          servers.each do |server|
            @server = server

            reply(build_server_embed)
          end
        end

        module ErrorMessage
          def self.no_servers(community_id:)
            ESM::Embed.build do |e|
              e.description = t("commands.servers.embed.error_messages.no_servers.description", community_id: community_id)
              e.add_field(
                name: t("commands.servers.embed.error_messages.no_servers.field_1.name"),
                value: t("commands.servers.embed.error_messages.no_servers.field_1.value")
              )
            end
          end
        end

        #########################
        # Command Methods
        #########################

        def build_server_embed
          ESM::Embed.build do |e|
            e.title = @server.server_name
            e.color = @server.online? ? :green : :red

            # Server_id, ip, port
            add_server_connection_info(e)

            if @server.online?
              e.add_field(name: t("commands.server.online_for"), value: "```#{@server.uptime}```")
              e.add_field(name: t("commands.server.restart_in"), value: "```#{@server.time_left_before_restart}```")
            else
              e.description =
                if @server.disconnected_at.nil?
                  t("commands.servers.offline")
                else
                  t("commands.servers.offline_for", time: @server.time_since_last_connection)
                end
            end
          end
        end

        def add_server_connection_info(e)
          e.add_field(name: t(:server_id), value: "```#{@server.server_id}```", inline: true)
          e.add_field(name: t(:ip), value: "```#{@server.server_ip}```", inline: true)
          e.add_field(name: t(:port), value: "```#{@server.server_port}```", inline: true)
        end
      end
    end
  end
end
