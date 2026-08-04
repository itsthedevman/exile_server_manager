# frozen_string_literal: true

module ESM
  module Exile
    class Player
      # A V1 server sends territories as a string map keyed by name (a quirk of
      # the old protocol). Normalize that into the array of {id, name} hashes the
      # instance expects up front, so nothing downstream branches on shape.
      def self.from_v1(server:, player:)
        data = player.to_h

        # V1 sends territories as a name => id map: a JSON string over the wire,
        # or a hash/OpenStruct once the response is parsed. Coerce either form to
        # a hash, then to the array of {id, name} the instance expects so
        # #territories never branches on shape.
        territories = data[:territories]
        territories = territories.parse_json if territories.is_a?(String)
        territories = territories.to_h if territories.respond_to?(:to_h)
        data[:territories] = territories.map { |name, id| {id:, name:} } if territories.is_a?(Hash)

        new(server:, player: data)
      end

      ##
      # Whether a set of player data describes a living player.
      #
      # A nil damage means Exile has no player row for the account at all, and a damage of 1 is the glitched,
      # unspawnable state the reset commands exist to clear. Both read as dead to whoever is looking.
      #
      # @param data [Hash] player data, symbol-keyed
      #
      # @return [Boolean] true when the account has a living player
      #
      def self.alive?(data)
        damage = data.to_h[:damage]

        !(damage.nil? || damage == 1)
      end

      def initialize(server:, player:)
        @server = server
        @data = player.to_h

        # Dead or absent players don't return every field.
        normalize
      end

      def name
        @data[:name]
      end

      def uid
        @data[:uid]
      end

      def alive?
        @alive
      end

      # Arma stores damage 0 (full health) to 1 (dead); surface it as a health %.
      def health
        return unless alive?

        (100 - (@data[:damage] * 100)).round(2)
      end

      def hunger
        @data[:hunger].round(2)
      end

      def thirst
        @data[:thirst].round(2)
      end

      def money
        @data[:money]
      end

      def locker
        @data[:locker]
      end

      # The database column is "score"; its player-facing name is "Respect".
      def score
        @data[:score]
      end

      alias_method :respect, :score

      def kills
        @data[:kills]
      end

      def deaths
        @data[:deaths]
      end

      def kd_ratio
        return 0 if deaths.zero?

        # These are returned as integers, cast to float
        (kills.to_f / deaths).round(2)
      end

      def first_connect_at
        @data[:first_connect_at]
      end

      def last_disconnect_at
        @data[:last_disconnect_at]
      end

      def total_connections
        @data[:total_connections]
      end

      def territories
        @territories ||= @data[:territories]
          .map { |territory| ESM::Exile::Territory.new(server: @server, territory:) }
          .sort_by { |territory| territory.name.to_s.downcase }
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
        @alive = self.class.alive?(@data)
        @data[:damage] ||= 1
        @data[:hunger] ||= 0
        @data[:thirst] ||= 0
        @data[:kills] ||= 0
        @data[:deaths] ||= 0
        @data[:money] ||= 0
        @data[:territories] ||= []
      end

      def add_general_field(embed)
        if alive?
          embed.add_field(
            name: "__#{I18n.t(:general)}__",
            value: [
              "**#{I18n.t(:health)}:**\n#{health}%\n",
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
          value: territories.join_map("\n") { |territory| "**#{territory.name}**: `#{territory.id}`" }
        )
      end
    end
  end
end
