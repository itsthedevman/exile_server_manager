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
    attribute :welcome_message_enabled, :boolean, default: true
    attribute :welcome_message, :string, default: ""
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

    module ESM
      ID = "452568470765305866"
    end

    def self.community_ids
      @community_ids ||= all.pluck(:community_id)
    end

    def self.correct(id)
      checker = DidYouMean::SpellChecker.new(dictionary: community_ids)
      checker.correct(id)
    end

    def self.find_by_community_id(id)
      default_scoped.includes(:servers).order(:community_id).where("community_id ilike ?", id).first
    end

    def self.find_by_guild_id(id)
      default_scoped.includes(:servers).order(:guild_id).where(guild_id: id).first
    end

    def self.find_by_server_id(id)
      return if id.blank?

      # esm_malden -> esm
      community_id = id.match(/([^\s]+)_[^\s]+/i)
      return if community_id.nil?

      find_by_community_id(community_id[1])
    end

    def self.from_discord(discord_server)
      return if discord_server.nil?

      community = order(:guild_id).where(guild_id: discord_server.id).first_or_initialize
      community.update!(community_name: discord_server.name)
      community
    end

    def logging_channel
      ::ESM.bot.channel(logging_channel_id)
    rescue
      nil
    end

    def discord_server
      ::ESM.bot.server(guild_id)
    rescue
      nil
    end

    def log_event(event, message)
      return if logging_channel_id.blank?

      # Only allow logging events to logging channel if permission has been given
      case event
      when :xm8
        return if !log_xm8_event
      when :discord_log
        return if !log_discord_log_event
      when :reconnect
        return if !log_reconnect_event
      when :error
        return if !log_error_event
      else
        raise ::ESM::Exception::Error, "Attempted to log :#{event} to #{guild_id} without explicit permission.\nMessage:\n#{message}"
      end

      # Check this first to avoid an infinite loop if the bot cannot send a message to this channel
      # since this method is called from the #deliver method for this exact reason.
      channel = logging_channel
      return if channel.nil?

      ::ESM.bot.deliver(message, to: channel)
    end

    def modifiable_by?(guild_member)
      return true if guild_member.permission?(:administrator) || guild_member.owner?

      # Check for roles
      dashboard_access_role_ids.any? { |role_id| guild_member.role?(role_id) }
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
      configurations = ::ESM::Command.configurations.map { |c| c.merge(community_id: id) }
      ::ESM::CommandConfiguration.import(configurations)
    end

    def create_notifications
      ::ESM::Notification::DEFAULTS.each do |category, notifications|
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

        ::ESM::Notification.import(notifications)
      end
    end
  end
end
