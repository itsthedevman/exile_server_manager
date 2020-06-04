# frozen_string_literal: true

module ESM
  class Community < ApplicationRecord
    before_create :generate_community_id
    after_create :create_command_configurations
    after_create :create_notifications

    attribute :community_id, :string
    attribute :community_name, :text
    attribute :community_website, :text
    attribute :guild_id, :string
    attribute :logging_channel_id, :string
    attribute :log_reconnect_event, :boolean, default: false
    attribute :log_xm8_event, :boolean, default: true
    attribute :player_mode_enabled, :boolean, default: true
    attribute :territory_admin_ids, :json, default: []
    attribute :command_prefix, :string, default: nil
    attribute :created_at, :datetime
    attribute :updated_at, :datetime
    attribute :deleted_at, :datetime

    has_many :command_configurations
    has_many :cooldowns
    has_many :notifications
    has_many :servers

    alias_attribute :name, :community_name

    module ESM
      ID = "414643176947843073"
      SPAM_CHANNEL = ENV["SPAM_CHANNEL"]
    end

    module Secondary
      ID = ENV["SECONDARY_COMMUNITY_ID"]
      SPAM_CHANNEL = ENV["SECONDARY_SPAM_CHANNEL"]
    end

    def self.community_ids
      @community_ids ||= self.all.pluck(:community_id)
    end

    def self.correct(id)
      checker = DidYouMean::SpellChecker.new(dictionary: community_ids)
      checker.correct(id)
    end

    def self.find_by_community_id(id)
      self.order(:community_id).where(community_id: id).first
    end

    def self.find_by_guild_id(id)
      self.order(:guild_id).where(guild_id: id).first
    end

    def self.find_by_server_id(id)
      # esm_malden -> esm
      community_id = id.match(/([^\s]+)_[^\s]+/i)[1]
      find_by_community_id(community_id)
    end

    def discord_server
      ::ESM.bot.server(self.guild_id)
    end

    def log_event(event, message)
      return if self.logging_channel_id.blank?

      # Only allow logging events to logging channel if permission has been given
      case event
      when :xm8
        return if !self.log_xm8_event
      else
        raise ::ESM::Exception::Error, "Attempted to log #{event} to #{self.guild_id} without explicit permission.\nMessage:\n#{message}"
      end

      # This will also handle resending
      ::ESM.bot.deliver(message, to: self.logging_channel_id)
    end

    private

    def generate_community_id
      return if self.community_id.present?

      count = 0
      new_id = nil

      loop do
        # Attempt to generate an id. Top rated comment from this answer: https://stackoverflow.com/a/88341
        new_id = ('a'..'z').to_a.sample(4).join
        count += 1

        # Our only saviors
        break if count > 10_000
        break if self.class.find_by_community_id(new_id).nil?
      end

      # Yup. Add to the community_ids so our spell checker works
      self.class.community_ids << new_id
      self.community_id = new_id
    end

    def create_command_configurations
      return if self.command_configurations.present?

      ::ESM::Command.create_configurations_for_community(self)
    end

    def create_notifications
      return if self.notifications.present?

      ::ESM::Notification::DEFAULTS.each do |category, notifications|
        notifications =
          notifications.map do |notification|
            {
              community_id: self.id,
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
