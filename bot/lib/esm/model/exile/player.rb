# frozen_string_literal: true

module ESM
  module Exile
    class Player
      def initialize(server:, player_data:)
        @server = server
        @data = player_data
        @alive = true

        # If the player is dead, not all information is returned.
        normalize
      end

      def name
        @data.name
      end

      def alive?
        @alive
      end

      # Arma stores the health as 0 (full) to 1 (dead)
      def damage
        (100 - (@data.damage * 100)).round(2)
      end

      def hunger
        @data.hunger.round(2)
      end

      def thirst
        @data.thirst.round(2)
      end

      def money
        @data.money
      end

      def locker
        @data.locker
      end

      def respect
        @data.score
      end

      def kills
        @data.kills
      end

      def deaths
        @data.deaths
      end

      def kd_ratio
        return 0 if deaths.zero?

        # These are returns as integers, cast to float
        (kills.to_f / deaths).round(2)
      end

      def territories
        @territories ||= begin
          territories = @data.territories

          # V1 - Wtf? Why did I send this as a hash?? And using the name as the key?? lol
          if territories.is_a?(String)
            territory = ImmutableStruct.define(:id, :name)
            territories = territories.to_h.map { |name, id| territory.new(id, name) }
          end

          territories.sort_by { |t| t.name.downcase }
        end
      end

      def to_embed
        ESM::Embed.build do |e|
          e.title = I18n.t("commands.me.embed.title", server_id: @server.server_id, user: name)

          add_general_field(e)
          add_currency_field(e)
          add_scoreboard_field(e)
          add_territories_field(e) if territories.present?
        end
      end

      private

      # Alive players return all of these fields.
      # Dead players return: locker, score, name, kills, deaths, territories
      def normalize
        @alive = false if @data.damage.nil? || @data.damage == 1
        @data.damage ||= 1
        @data.hunger ||= 0
        @data.thirst ||= 0
        @data.kills ||= 0
        @data.deaths ||= 0
        @data.money ||= 0
        @data.territories ||= []
      end

      def add_general_field(embed)
        if alive?
          embed.add_field(
            name: "__#{I18n.t(:general)}__",
            value: [
              "**#{I18n.t(:health)}:**\n#{damage}%\n",
              "**#{I18n.t(:hunger)}:**\n#{hunger}%\n",
              "**#{I18n.t(:thirst)}:**\n#{thirst}%\n"
            ].join("\n"),
            inline: true
          )
        else
          embed.add_field(
            name: "__#{I18n.t(:general)}__",
            value: "**#{I18n.t(:you_are_dead)}**"
          )
        end
      end

      def add_currency_field(embed)
        values = [
          "**#{I18n.t(:money)}:**\n#{alive? ? money.to_poptab : "**#{I18n.t(:you_are_dead)}**"}\n",
          "**#{I18n.t(:locker)}:**\n#{locker.to_poptab}\n",
          "**#{I18n.t(:respect)}:**\n#{respect.to_readable}\n"
        ]

        embed.add_field(name: "__#{I18n.t(:currency)}__", value: values.join("\n"), inline: true)
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
          name: "__#{I18n.t("territories")}__",
          value: territories.format(join_with: "\n") { |territory| "**#{territory.name}**: `#{territory.id}`" }
        )
      end
    end
  end
end
