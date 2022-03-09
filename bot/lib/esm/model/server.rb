# frozen_string_literal: true

module ESM
  class Server < ApplicationRecord
    before_create :generate_key
    after_create :create_server_setting
    after_create :create_server_reward

    attribute :server_id, :string
    attribute :community_id, :integer
    attribute :server_name, :text
    attribute :server_key, :text
    attribute :server_ip, :string
    attribute :server_port, :string
    attribute :server_start_time, :datetime
    attribute :disconnected_at, :datetime
    attribute :created_at, :datetime
    attribute :updated_at, :datetime

    default_scope { where(deleted_at: nil) }

    belongs_to :community

    has_many :cooldowns, dependent: :destroy
    has_many :logs, dependent: :destroy
    has_many :server_mods, dependent: :destroy
    has_one :server_reward, dependent: :destroy
    has_one :server_setting, dependent: :destroy
    has_many :territories, dependent: :destroy
    has_many :user_gamble_stats, dependent: :destroy
    has_many :user_notification_preferences, dependent: :destroy

    def self.find_by_server_id(id)
      self.order(:server_id).where("server_id ilike ?", id).first
    end

    def territories
      ESM::Territory.order(:server_id).where(server_id: self.id).order(:territory_level)
    end

    def online?
      ESM::Websocket.connected?(self.server_id)
    end

    def uptime
      ESM::Time.distance_of_time_in_words(self.server_start_time)
    end

    def time_left_before_restart
      restart_time = self.server_start_time + self.server_setting.server_restart_hour.hours + self.server_setting.server_restart_min.minutes
      ESM::Time.distance_of_time_in_words(restart_time)
    end

    def time_since_last_connection
      ESM::Time.distance_of_time_in_words(self.disconnected_at)
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

    def generate_key
      return if !self.server_key.blank?

      self.server_key = 7.times.map { SecureRandom.uuid.gsub("-", "") }.join("")
    end

    def create_server_setting
      return if self.server_setting.present?

      self.server_setting = ESM::ServerSetting.create!(server_id: self.id)
    end

    def create_server_reward
      return if self.server_reward.present?

      self.server_reward = ESM::ServerReward.create!(server_id: self.id)
    end
  end
end
