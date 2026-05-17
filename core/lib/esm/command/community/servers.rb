# frozen_string_literal: true

module ESM
  module Command
    module Community
      class Servers < ApplicationCommand
        #################################
        #
        # Arguments (required first, then order matters)
        #

        # See Argument::TEMPLATES[:community_id]
        argument :community_id, display_name: :for

        #
        # Configuration
        #

        command_type :player

        does_not_require :registration

        #################################

        def on_execute
          servers = ESM::Server.where(community_id: target_community.id, server_visibility: :public)
            .sort_by { |s| s.server_name.downcase }
            .sort { |s| s.connected? ? 0 : 1 }

          check_for_no_servers!(servers)

          servers.each do |server|
            reply(build_server_embed(server))
          end
        end

        private

        def check_for_no_servers!(servers)
          return if servers.present?

          raise_error!(:no_servers, community_id: arguments.community_id)
        end

        def build_server_embed(server)
          ESM::Embed.build do |e|
            e.title = server.server_name.presence || ""
            e.color = server.connected? ? :green : :red

            # Server_id, ip, port
            add_server_connection_info(e, server)

            if server.connected?
              e.add_field(name: I18n.t("commands.server.online_for"), value: "```#{server.uptime}```")
              e.add_field(name: I18n.t("commands.server.restart_in"), value: "```#{server.time_left_before_restart}```")
            else
              e.description =
                if server.disconnected_at.nil?
                  I18n.t("commands.servers.offline")
                else
                  I18n.t("commands.servers.offline_for", time: server.time_since_last_connection)
                end
            end
          end
        end

        def add_server_connection_info(e, server)
          e.add_field(name: I18n.t(:server_id), value: "```#{server.server_id}```", inline: true)
          e.add_field(name: I18n.t(:ip), value: "```#{server.server_ip}```", inline: true)
          e.add_field(name: I18n.t(:port), value: "```#{server.server_port}```", inline: true)
        end
      end
    end
  end
end
