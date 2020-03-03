# frozen_string_literal: true

module ESM
  class Server < ApplicationRecord
    before_create :generate_key
    after_save :create_server_setting
    after_save :create_server_reward

    attribute :server_id, :string
    attribute :community_id, :integer
    attribute :server_name, :text
    attribute :server_key, :text
    attribute :server_ip, :string
    attribute :server_port, :string
    attribute :server_start_time, :datetime
    attribute :disconnected_at, :datetime
    attribute :is_premium, :boolean, default: false
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
    has_many :user_gamblings, dependent: :destroy
    has_many :user_notification_preferences, dependent: :destroy

    def self.find_by_server_id(id)
      self.order(:server_id).where(server_id: id).first
    end

    def territories
      ESM::Territory.order(:server_id).where(server_id: self.id).order(:territory_level)
    end

    def premium?
      self.is_premium
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

    private

    def generate_key
      return if !self.server_key.blank?

      self.server_key = 7.times.map { SecureRandom.uuid.gsub("-", "") }.join("")
    end

    def create_server_setting
      return if self.server_setting.present? || ESM.env.test?

      self.server_setting = ESM::ServerSetting.create!(server_id: self.id)
    end

    def create_server_reward
      return if self.server_reward.present? || ESM.env.test?

      self.server_reward = ESM::ServerReward.create!(server_id: self.id)
    end
  end
end
