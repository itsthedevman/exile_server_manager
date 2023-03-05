# frozen_string_literal: true

module ESM
  module Arma
    class Player
      def initialize(server:, player:)
        @server = server
        @player = player

        # If the player is dead, not all information is returned.
        normalize
      end

      def name
        @player.name
      end

      # Arma stores the health as 0 (full) to 1 (dead)
      def damage
        (100 - (@player.damage * 100)).round(2)
      end

      def hunger
        @player.hunger.round(2)
      end

      def thirst
        @player.thirst.round(2)
      end

      def money
        @player.money
      end

      def locker
        @player.locker
      end

      def respect
        @player.score
      end

      # Apparently some databases had nil values...
      def kills
        @player.kills
      end

      # Apparently some databases had nil values...
      def deaths
        @player.deaths
      end

      def kd_ratio
        return 0 if deaths.zero?

        # These are returns as integers, cast to float
        (kills.to_f / deaths).round(2)
      end

      def territories
        @territories ||= @player.territories.to_h
      end

      def to_embed
        ESM::Embed.build do |e|
          e.title = I18n.t("commands.me.embed.title", server_id: @server.server_id, user: name)

          add_general_field(e)
          add_currency_field(e)
          add_scoreboard_field(e)
          add_territories_field(e) if !territories.blank?
        end
      end

      private

      # Alive players return all of these fields.
      # Dead players return: locker, score, name, kills, deaths, territories
      def normalize
        # If damage is nil, the player is dead (1)
        @player.damage ||= 1
        @player.hunger ||= 0
        @player.thirst ||= 0
        @player.kills ||= 0
        @player.deaths ||= 0
        @player.money ||= 0
        @player.territories ||= {}
      end

      def add_general_field(embed)
        embed.add_field(
          name: "__#{I18n.t(:general)}__",
          value: [
            "**#{I18n.t(:health)}:**\n#{damage}%\n",
            "**#{I18n.t(:hunger)}:**\n#{hunger}%\n",
            "**#{I18n.t(:thirst)}:**\n#{thirst}%\n"
          ].join("\n"),
          inline: true
        )
      end

      def add_currency_field(embed)
        embed.add_field(
          name: "__#{I18n.t(:currency)}__",
          value: [
            "**#{I18n.t(:money)}:**\n#{money.to_poptab}\n",
            "**#{I18n.t(:locker)}:**\n#{locker.to_poptab}\n",
            "**#{I18n.t(:respect)}:**\n#{respect.to_readable}\n"
          ].join("\n"),
          inline: true
        )
      end

      def add_scoreboard_field(embed)
        embed.add_field(
          name: "__#{I18n.t(:scoreboard)}__",
          value: [
            "**#{I18n.t(:kills)}:**\n#{kills.to_readable}\n",
            "**#{I18n.t(:deaths)}:**\n#{deaths.to_readable}\n",
            "**#{I18n.t(:kd_ratio)}:**\n#{kd_ratio}\n"
          ].join("\n"),
          inline: true
        )
      end

      def add_territories_field(embed)
        embed.add_field(
          name: I18n.t("territories"),
          value: territories.format(join_with: "\n") { |name, id| "**#{name}**: `#{id}`" }
        )
      end
    end
  end
end
