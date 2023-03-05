# frozen_string_literal: true

module ESM
  class Test
    # Don't forget to add new entries to .reset!
    class << self
      DATA = YAML.load_file(File.expand_path("./spec/test_data.yml")).deep_symbolize_keys.freeze

      attr_reader :response
      attr_writer :messages
      attr_accessor :skip_cooldown, :block_outbound_messages

      def messages
        @messages ||= Messages.new
      end

      def outbound_server_messages
        @outbound_server_messages ||= Messages.new
      end

      def inbound_server_messages
        @inbound_server_messages ||= Messages.new
      end

      def data
        @data ||= lambda do
          data = DATA.deep_dup
          redis.set("test_data", data.to_json)

          data
        end.call
      end

      # Attempt to simulate a random community for tests
      #
      # @note The type of community controls what user type is selected
      # @see #reset!
      def community(*args, type: @community_type)
        @community ||= FactoryBot.create(type, :player_mode_disabled, *args)
      end

      def second_community(*args)
        @second_community ||= FactoryBot.create(@second_community_type, :player_mode_disabled, *args)
      end

      # Attempt to simulate random users for tests
      #
      # @note The type of community controls what user type is selected
      # @see #reset!
      def user(*args, type: @user_type)
        args = [type] + args

        counter = 0
        loop do
          counter += 1
          user = FactoryBot.build(*args)

          if counter > 10
            ap ESM::User.all.to_a
            raise "Failed to create unique user. Decrease number of calls to ESM::Test.user or add more users to test_data.yml"
          end
          break user if user.valid? && user.save
        end
      end

      def server
        FactoryBot.create(:server, community_id: community.id)
      end

      def second_server
        FactoryBot.create(:server, community_id: second_community.id)
      end

      def channel(opts = {})
        community = opts.delete(:in) || community
        guild_type = community&.guild_type || :primary

        id = data[guild_type][:channels].sample
        ESM.bot.channel(id)
      end

      def redis
        @redis ||= Redis.new(ESM::REDIS_OPTS)
      end

      def response=(value)
        @response = {
          message: {
            content: value
          }
        }.to_ostruct
      end

      def steam_uid
        data[:steam_uids].delete(data[:steam_uids].sample)
      end

      def reset!
        @data = nil
        @response = nil
        @messages = nil
        @outbound_server_messages = nil
        @inbound_server_messages = nil
        @community = nil
        @second_community = nil

        @skip_cooldown = false
        @block_outbound_messages = false

        @communities = %i[primary_community secondary_community]
        @community_type = @communities.sample
        @user_type = (@community_type == :primary_community) ? :user : :secondary_user
        @second_community_type = @communities.find { |type| type != @community_type }

        # Clear the test list in Redis
        redis.del("test")
      end

      def wait_for_response(timeout: nil)
        timeout ||= 5

        # Offset the fact that we check every 0.25s
        timeout *= 4
        counter = 0

        while response.blank? && counter < timeout
          sleep(0.1)
          counter += 1
        end

        output = response
        @response = nil

        output
      end

      def reply_in(message, wait: 1)
        Thread.new do
          sleep(wait)
          self.response = message
        end
      end

      def wait_until(timeout: 30)
        # Offset the fact that we check every 0.25s
        timeout *= 4
        counter = 0

        while counter < timeout
          sleep(0.1)
          counter += 1

          # I don't have this in the conditional above because I want it to sleep at least once
          return if yield == true
        end

        raise StandardError, "Timeout!"
      end
    end
  end
end
