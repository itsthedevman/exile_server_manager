# frozen_string_literal: true

module ESM
  class Server < ApplicationRecord
    before_create :generate_public_id
    before_create :generate_key
    after_create :create_server_setting
    after_create :create_default_reward

    attribute :public_id, :uuid
    attribute :server_id, :string
    attribute :community_id, :integer
    attribute :server_name, :text
    attribute :server_key, :text
    attribute :server_ip, :string
    attribute :server_port, :string
    attribute :server_start_time, :datetime
    attribute :server_version, :string
    enum :server_visibility, {private: 0, public: 1}, default: :public, suffix: :visibility
    attribute :disconnected_at, :datetime
    attribute :created_at, :datetime
    attribute :updated_at, :datetime

    belongs_to :community

    has_many :cooldowns, dependent: :destroy
    has_many :logs, dependent: :destroy
    has_many :server_mods, dependent: :destroy
    has_many :server_rewards, dependent: :destroy
    has_one :server_setting, dependent: :destroy
    has_many :territories, dependent: :destroy
    has_many :user_gamble_stats, dependent: :destroy
    has_many :user_notification_preferences, dependent: :destroy
    has_many :user_notification_routes, dependent: :destroy, foreign_key: :source_server_id

    scope :by_server_id_fuzzy, ->(id) { where("server_id ilike ?", "%#{id}%") }

    def self.find_by_public_id(id)
      includes(:community).order(:public_id).where(public_id: id).first
    end

    def self.find_by_server_id(id)
      includes(:community).order(:server_id).where("server_id ilike ?", id).first
    end

    def self.server_ids
      ::ESM.cache.fetch("server_ids", expires_in: ESM.config.cache.server_ids) do
        ApplicationRecord.connection_pool.with_connection { pluck(:server_id) }
      end
    end

    # Checks to see if there are any corrections and provides them for the server id
    def self.correct_id(server_id)
      checker = DidYouMean::SpellChecker.new(dictionary: server_ids)
      checker.correct(server_id)
    end

    def token
      @token ||= {access: public_id, secret: server_key}
    end

    # V1
    def server_reward
      server_rewards.default
    end

    def territories
      ESM::Territory.order(:server_id).where(server_id: id).order(:territory_level)
    end

    delegate :send_message, :send_error, to: :connection

    #
    # Returns the server's current version
    #
    # @return [Semantic::Version] Returns a version 2.0.0 or greater if there is a connection. If there is no connection, 1.0.0 is assumed.
    #
    def version
      Semantic::Version.new(server_version || "1.0.0")
    end

    def version?(expected_version)
      version >= Semantic::Version.new(expected_version)
    end

    def v2?
      version?("2.0.0")
    end

    def connection
      ESM.connection_server.client(public_id)
    end

    def connected?
      return ESM::Websocket.connected?(server_id) unless v2? # V1

      !connection.nil?
    end

    def uptime
      return "Offline" if server_start_time.nil?

      ESM::Time.distance_of_time_in_words(server_start_time)
    end

    def time_left_before_restart
      restart_time = server_start_time + server_setting.server_restart_hour.hours + server_setting.server_restart_min.minutes
      ESM::Time.distance_of_time_in_words(restart_time)
    end

    def time_since_last_connection
      ESM::Time.distance_of_time_in_words(disconnected_at)
    end

    def user_gamble_stats
      @user_gamble_stats ||= super
    end

    def longest_current_streak
      user_gamble_stats.order(current_streak: :desc).first
    end

    def longest_win_streak
      user_gamble_stats.order(longest_win_streak: :desc).first
    end

    def longest_losing_streak
      user_gamble_stats.order(longest_loss_streak: :desc).first
    end

    def most_poptabs_won
      user_gamble_stats.order(total_poptabs_won: :desc).first
    end

    def most_poptabs_lost
      user_gamble_stats.order(total_poptabs_loss: :desc).first
    end

    # Sends a message to the client with a unique ID then logs the ID to the community's logging channel
    def log_error(log_message)
      uuid = SecureRandom.uuid

      message = ESM::Message.new.add_error("message", "[#{uuid}] #{log_message}")
      send_error(message)

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

    private

    def generate_public_id
      return if public_id.present?

      self.public_id = SecureRandom.uuid
    end

    # Idk how to store random bytes in redis (Dang you NULL!)
    KEY_CHARS = [
      "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", "!", "#", "$", "%", "&", "'", "(", ")", "*", "+", ",", "-", ".", ":", ";", "<", "=", ">", "?", "@", "[", "]", "^", "_", "`", "{", "|", "}", "~"
    ].shuffle.freeze

    def generate_key
      return if server_key.present?

      self.server_key = Array.new(64).map { KEY_CHARS.sample }.join
    end

    def create_server_setting
      return if server_setting.present?

      self.server_setting = ESM::ServerSetting.create!(server_id: id)
    end

    def create_default_reward
      server_rewards.create!(server_id: id)
    end
  end
end
