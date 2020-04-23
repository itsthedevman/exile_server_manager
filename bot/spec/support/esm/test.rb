# frozen_string_literal: true

module ESM
  class Test
    class << self
      attr_reader :response
      attr_writer :messages
      attr_accessor :skip_cooldown
    end

    # Attempt to simulate a random community for tests
    #
    # @note The type of community controls what user type is selected
    # @see #reset!
    def self.community
      @community ||= FactoryBot.create(@community_type, :player_mode_disabled)
    end

    # Attempt to simulate random users for tests
    #
    # @note The type of community controls what user type is selected
    # @see #reset!
    def self.user
      @user ||= FactoryBot.create(@user_type)
    end

    # Creates a second user that isn't #user
    def self.second_user
      @second_user ||= FactoryBot.create(@user_type, not_user: user)
    end

    def self.server
      @server ||= FactoryBot.create(:server, community_id: community.id)
    end

    def self.response=(value)
      return @response = nil if value.nil?

      @response = {
        message: {
          content: value
        }
      }.to_ostruct
    end

    def self.messages
      @messages ||= []
    end

    def self.reset!
      @response = nil
      @messages = []
      @community = nil
      @server = nil
      @user = nil
      @second_user = nil

      @community_type = %i[esm_community secondary_community].sample
      @user_type = @community_type == :esm_community ? :user : :secondary_user
    end

    # I hate this code, it doesn't make me happy
    def self.await(timeout: 5)
      # Offset the fact that we check every 0.25s
      timeout *= 4
      counter = 0

      while counter < timeout
        sleep(0.25)
        counter += 1

        # I don't have this in the conditional above because I want it to sleep at least once
        break if ESM::Test.response.present?
      end

      ESM::Test.response
    end

    def self.await_and_reply(message, wait: 1)
      Thread.new do
        sleep(wait)
        ESM::Test.response = message
      end
    end

    def self.wait_until(timeout: 30, &block)
      # Offset the fact that we check every 0.25s
      timeout *= 4
      counter = 0

      while counter < timeout
        sleep(0.25)
        counter += 1

        # I don't have this in the conditional above because I want it to sleep at least once
        return if yield == true
      end

      raise StandardError, "Timeout!"
    end
  end
end
