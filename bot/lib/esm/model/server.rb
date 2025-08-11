# frozen_string_literal: true

module ESM
  class Server < ApplicationRecord
    def self.server_ids
      ESM.cache.fetch("server_ids", expires_in: ESM.config.cache.server_ids) do
        ESM::Database.with_connection { pluck(:server_id) }
      end
    end

    # Checks to see if there are any corrections and provides them for the server id
    def self.correct_id(server_id)
      checker = DidYouMean::SpellChecker.new(dictionary: server_ids)
      checker.correct(server_id)
    end

    def connection
      ESM::Connection::Server.client(public_id)
    end

    def connected?
      return ESM::Websocket.connected?(server_id) unless v2? # V1

      !connection.nil?
    end

    delegate :send_message, :send_error, to: :connection, allow_nil: true

    # Sends a message to the client with a unique ID then logs the ID to the community's logging channel
    def log_error(log_message)
      uuid = SecureRandom.uuid
      send_error("[#{uuid}] #{log_message}")

      return if community.logging_channel_id.blank?

      ESM.bot.deliver(
        I18n.t("exceptions.extension_error", server_id: server_id, id: uuid),
        to: community.logging_channel_id
      )
    end

    #
    # Sends the provided SQF code to the linked connection.
    #
    # @param code [String] Valid and error free SQF code as a string
    # @param execute_on [String] Valid options: "server", "player", "all"
    # @param player [ESM::User, nil] The player who initiated the request
    #   Note: This technically can be `nil` but errors triggered by this function may look weird
    # @param target [ESM::User, ESM::User::Ephemeral, nil]
    #   The user to execute the code on if execute_on is "player"
    #
    # @return [Any] The result of the SQF code.
    #
    # @note: The result is ran through a JSON parser.
    #   The type may not be what you expect, but it will be consistent.
    #   For example, an empty hash map will always be represented by an empty array []
    #
    def execute_sqf!(code, execute_on: "server", player: nil, target: nil)
      message = ESM::Message.new.set_type(:call)
        .set_data(
          function_name: "ESMs_command_sqf",
          execute_on: "server",
          code: code
        )
        .set_metadata(player:, target:)

      response = send_message(message).data.result

      # Check if it's JSON like
      result = ESM::JSON.parse(response.to_s)
      return response if result.nil?

      # Check to see if its a hashmap
      possible_hashmap = ESM::Arma::HashMap.from(result)
      return result if possible_hashmap.nil?

      result
    end

    def status_embed(status, reason: "")
      ESM::Embed.build do |e|
        e.color = (status == :connected) ? :green : :red
        e.title = "#{server_name} (`#{server_id}`)"

        if status == :connected
          e.description = I18n.t("server_connected")
        else
          description = I18n.t("server_disconnect.base")
          description += "\n#{reason}" if reason.present?

          e.description = description

          e.footer = I18n.t("server_disconnect.footer")
        end

        e.add_field(name: I18n.t("uptime"), value: uptime, inline: true)
      end
    end
  end
end
