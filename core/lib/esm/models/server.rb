# frozen_string_literal: true

module ESM
  class Server < ApplicationRecord
    # =============================================================================
    # INITIALIZE
    # =============================================================================

    # Idk how to store random bytes in redis (Dang you NULL!)
    KEY_CHARS = [
      "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", "!", "#", "$", "%", "&", "'", "(", ")", "*", "+", ",", "-", ".", ":", ";", "<", "=", ">", "?", "@", "[", "]", "^", "_", "`", "{", "|", "}", "~"
    ].shuffle.freeze

    # =============================================================================
    # DATA STRUCTURE
    # =============================================================================

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
    attribute :ui_version, :string
    attribute :disconnected_at, :datetime
    attribute :created_at, :datetime
    attribute :updated_at, :datetime

    # =============================================================================
    # ASSOCIATIONS
    # =============================================================================

    belongs_to :community

    has_many :cooldowns, dependent: :destroy
    has_many :logs, dependent: :destroy
    has_many :server_mods, dependent: :destroy
    has_many :server_rewards, dependent: :destroy
    has_one :server_setting, dependent: :destroy
    has_many :territories, -> { order(:territory_level) }, dependent: :destroy
    has_many :user_gamble_stats, dependent: :destroy
    has_many :user_notification_preferences, dependent: :destroy
    has_many :user_notification_routes, dependent: :destroy, foreign_key: :source_server_id

    # =============================================================================
    # VALIDATIONS
    # =============================================================================

    validates :public_id, uniqueness: true, presence: true

    # =============================================================================
    # CALLBACKS
    # =============================================================================

    before_validation :generate_public_id, on: :create
    before_validation :generate_key, on: :create

    after_create :create_server_setting
    after_create :create_default_reward

    # =============================================================================
    # SCOPES
    # =============================================================================

    scope :matching_server_id, ->(id) { where("server_id ilike ?", id) }
    scope :by_server_id_fuzzy, ->(id) { where("server_id ilike ?", "%#{id}%") }

    # =============================================================================
    # CLASS METHODS
    # =============================================================================

    def self.find_by_public_id(id)
      includes(:community).order(:public_id).where(public_id: id).first
    end

    def self.find_by_server_id(id)
      includes(:community).matching_server_id(id).first
    end

    # =============================================================================
    # INSTANCE METHODS
    # =============================================================================

    def local_id
      # Removes the community ID from the server ID
      server_id.split("_", 2).second
    end

    def token
      @token ||= {access: public_id, secret: server_key}
    end

    # V1
    def server_reward
      server_rewards.default
    end

    def version
      Semantic::Version.new(server_version || "1.0.0")
    end

    def version?(expected_version)
      version >= Semantic::Version.new(expected_version)
    end

    def v2?
      version?("2.0.0")
    end

    def uptime
      return "Offline" if server_start_time.nil?

      ESM::Time.distance_of_time_in_words(server_start_time)
    end

    def time_left_before_restart
      return "Offline" if server_start_time.nil?

      restart_time = server_start_time +
        server_setting.server_restart_hour.hours +
        server_setting.server_restart_min.minutes

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

    private

    def generate_public_id
      return if public_id.present?

      self.public_id = SecureRandom.uuid
    end

    def generate_key
      return if server_key.present?

      self.server_key = Array.new(64).map { KEY_CHARS.sample }.join
    end

    def create_server_setting
      return if server_setting.present?

      self.server_setting = ESM::ServerSetting.create!(server_id: id)
    end

    def create_default_reward
      return if server_rewards.default.exists?

      server_rewards.create!(server_id: id)
    end
  end
end
