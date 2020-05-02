# frozen_string_literal: true

module ESM
  module Command
    module Server
      class Me < ESM::Command::Base
        type :player

        define :enabled, modifiable: true, default: true
        define :whitelist_enabled, modifiable: true, default: false
        define :whitelisted_role_ids, modifiable: true, default: []
        define :allowed_in_text_channels, modifiable: true, default: true
        define :cooldown_time, modifiable: true, default: 2.seconds

        requires :registration

        argument :server_id

        def discord
          deliver!(query: "player_info", uid: current_user.esm_user.steam_uid)
        end

        def server
          # Apparently some databases had nil values...
          normalize_response

          # What if the player is dead?
          embed =
            ESM::Embed.build do |e|
              e.title = I18n.t("commands.me.embed.title", server_id: target_server.server_id, user: @response.name)

              add_general_field(e)
              add_currency_field(e)
              add_scoreboard_field(e)

              e.add_field(name: I18n.t("territories"), value: build_territory_field) if !@response.territories.to_h.blank?
            end

          reply(embed)
        end

        #########################
        # Command Methods
        #########################
        # @private
        # Normalizes the response so we don't crash
        def normalize_response
          @response.kills ||= 0
          @response.deaths ||= 0
        end

        def add_general_field(embed)
          embed.add_field(
            name: "General",
            value: [
              # Arma stores the health as 0 (full) to 1 (dead)
              "**_#{I18n.t(:damage)}:_**\n#{(100 - (@response.damage * 100)).round(2)}%",
              "**_#{I18n.t(:hunger)}:_**\n#{@response.hunger.round(2)}%",
              "**_#{I18n.t(:thirst)}:_**\n#{@response.thirst.round(2)}%"
            ].join("\n"),
            inline: true
          )
        end

        def add_currency_field(embed)
          embed.add_field(
            name: "Currency",
            value: [
              "**_#{I18n.t(:money)}:_**\n#{@response.money.to_poptab}",
              "**_#{I18n.t(:locker)}:_**\n#{@response.locker.to_poptab}",
              "**_#{I18n.t(:respect)}:_**\n#{@response.score.to_readable}"
            ].join("\n"),
            inline: true
          )
        end

        def add_scoreboard_field(embed)
          embed.add_field(
            name: "Scoreboard",
            value: [
              "**_#{I18n.t(:kills)}:_**\n#{@response.kills.to_readable}",
              "**_#{I18n.t(:deaths)}:_**\n#{@response.deaths.to_readable}",
              "**_#{I18n.t(:kd_ratio)}:_**\n#{kd_ratio}"
            ].join("\n"),
            inline: true
          )
        end

        def build_territory_field
          @response.territories.to_h.format(join_with: "\n") do |name, id|
            "**#{name}**: `#{id}`"
          end
        end

        def kd_ratio
          return 0 if @response.deaths.zero?

          # These are returns as integers, cast to float
          (@response.kills.to_f / @response.deaths).round(2)
        end
      end
    end
  end
end
