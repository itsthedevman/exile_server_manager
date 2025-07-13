# frozen_string_literal: true

module ESM
  class Community < ApplicationRecord
    ALPHABET = ("a".."z").to_a.freeze

    before_create :generate_community_id
    before_create :generate_public_id
    after_create :create_command_configurations
    after_create :create_notifications

    attribute :public_id, :uuid
    attribute :community_id, :string
    attribute :community_name, :text
    attribute :guild_id, :string
    attribute :logging_channel_id, :string
    attribute :log_reconnect_event, :boolean, default: false
    attribute :log_xm8_event, :boolean, default: true
    attribute :log_discord_log_event, :boolean, default: true
    attribute :log_error_event, :boolean, default: true
    attribute :player_mode_enabled, :boolean, default: true
    attribute :territory_admin_ids, :json, default: []
    attribute :dashboard_access_role_ids, :json, default: []
    attribute :command_prefix, :string, default: nil
    attribute :welcome_message_enabled, :boolean, default: true
    attribute :welcome_message, :string, default: ""
    attribute :allow_v2_servers, :boolean, default: false
    attribute :created_at, :datetime
    attribute :updated_at, :datetime

    has_many :command_configurations, dependent: :destroy
    has_many :cooldowns, dependent: :destroy
    has_many :id_defaults, class_name: "CommunityDefault", dependent: :destroy
    has_many :notifications, dependent: :destroy
    has_many :servers, dependent: :destroy
    has_many :user_aliases, dependent: :nullify
    has_many :user_defaults, dependent: :nullify
    has_many :user_notification_routes, foreign_key: :destination_community_id, dependent: :destroy

    alias_attribute :name, :community_name

    def self.correct(id)
      checker = DidYouMean::SpellChecker.new(dictionary: community_ids)
      checker.correct(id)
    end

    def self.find_by_community_id(id)
      includes(:servers).order(:community_id).where("community_id ilike ?", id).first
    end

    def self.find_by_guild_id(id)
      includes(:servers).order(:guild_id).where(guild_id: id).first
    end

    def self.find_by_server_id(id)
      return if id.blank?

      joins(:servers).order(:guild_id).where(servers: {server_id: id}).first
    end

    def self.servers_by_community
      communities = Community.includes(:servers).joins(:servers).order(:community_id)

      communities.map do |community|
        servers = community.servers.order(:server_id).select(:server_id, :server_name)

        {
          name: "[#{community.community_id}] #{community.community_name}",
          servers: servers.map(&:clientize)
        }
      end
    end

    def self.from_discord(discord_server)
      return if discord_server.nil?

      community = order(:guild_id).where(guild_id: discord_server.id).first_or_initialize
      community.update!(community_name: discord_server.name)
      community
    end

    private

    def generate_community_id
      return if community_id.present?

      count = 0
      new_id = nil

      loop do
        # Attempt to generate an id. Top rated comment from this answer: https://stackoverflow.com/a/88341
        new_id = ALPHABET.sample(4).join
        count += 1

        # Our only saviors
        break if count > 10_000
        break if self.class.find_by_community_id(new_id).nil?
      end

      # Yup. Add to the community_ids so our spell checker works
      self.class.community_ids << new_id
      self.community_id = new_id
    end

    def generate_public_id
      return if public_id.present?

      self.public_id = SecureRandom.uuid
    end

    def create_command_configurations
      configurations = ESM::Command.configurations.map { |c| c.merge(community_id: id) }
      ESM::CommandConfiguration.import(configurations)
    end

    def create_notifications
      ESM::Notification::DEFAULTS.each do |category, notifications|
        notifications =
          notifications.map do |notification|
            {
              community_id: id,
              notification_type: notification["type"],
              notification_title: notification["title"],
              notification_description: notification["description"],
              notification_color: notification["color"],
              notification_category: category
            }
          end

        ESM::Notification.import(notifications)
      end
    end
  end
end
