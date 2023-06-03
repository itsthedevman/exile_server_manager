# frozen_string_literal: true

module ESM
  module Command
    class Base
      module Helpers
        # The user that executed the command
        def current_user
          return @current_user if defined?(@current_user) && @current_user.present?
          return if event&.user.nil?

          user = ESM::User.where(discord_id: event&.user&.id).first_or_initialize
          user.update(
            discord_username: event&.user&.name,
            discord_discriminator: event&.user&.discriminator
          )

          # Save some cycles
          discord_user = user.discord_user
          discord_user.instance_variable_set(:@esm_user, user)

          # Return back the modified discord user
          @current_user = discord_user
        end

        # @return [ESM::Community, nil] The community the command was executed from. Nil if sent from Direct Message
        def current_community
          return @current_community if defined?(@current_community) && @current_community.present?
          return if event&.server.nil?

          @current_community = ESM::Community.find_by_guild_id(event&.server&.id)
        end

        # @return [ESM::Cooldown] The cooldown for this command and user
        def current_cooldown
          @current_cooldown ||= current_cooldown_query.first
        end

        def current_channel
          @current_channel ||= event&.channel
        end

        # @return [ESM::Server, nil] The server that the command was executed for
        def target_server
          @target_server ||= begin
            return nil if arguments.server_id.blank?

            ESM::Server.find_by_server_id(arguments.server_id)
          end
        end

        # @return [ESM::Community, nil] The community that the command was executed for
        def target_community
          @target_community ||= lambda do
            return ESM::Community.find_by_community_id(arguments.community_id) if arguments.community_id.present?

            target_server&.community
          end.call
        end

        # @return [ESM::User, nil] The user that the command was executed against
        def target_user
          return @target_user if defined?(@target_user) && @target_user.present?
          return if arguments.target.nil?

          # Store for later
          target = arguments.target

          # Attempt to parse first. Target could be steam_uid, discord id, or mention
          user = ESM::User.parse(target)

          # No user was found. Don't create a user from a steam UID
          #   target is a steam_uid WITHOUT a db user. -> Exit early. Use a placeholder user
          return @target_user = ESM::TargetUser.new(target) if user.nil? && target.steam_uid?

          # Past this point:
          #   target is a steam_uid WITH a db user -> Continue
          #   target is a discord ID or discord mention WITH a db user -> Continue
          #   target is a discord ID or discord mention WITHOUT a db user -> Continue, we'll create a user

          # Remove the tag bits if applicable
          target.gsub!(/[<@!&>]/, "") if ESM::Regex::DISCORD_TAG_ONLY.match(target)

          # Get the discord user from the ID or the previous db entry
          discord_user = user.nil? ? ESM.bot.user(target) : user.discord_user

          # Nothing we can do if we don't have a discord user
          return if discord_user.nil?

          # Create the user if its nil
          user = ESM::User.new(discord_id: target) if user.nil?
          user.update(discord_username: discord_user.name, discord_discriminator: discord_user.discriminator)

          # Save some cycles
          discord_user.instance_variable_set(:@esm_user, user)

          # Return back the modified discord user
          @target_user = discord_user
        end

        # Sometimes we're given a steamUID that may not be linked to a discord user
        # But, the command can work without the registered part.
        #
        # @return [String, nil] The steam uid from given argument or the steam uid registered to the target_user (which may be nil)
        def target_uid
          return if arguments.target.nil?

          @target_uid ||= lambda do
            arguments.target.steam_uid? ? arguments.target : target_user&.steam_uid
          end.call
        end

        # @return [Boolean] If the current user is the target user.
        def same_user?
          return false if target_user.nil?

          current_user.steam_uid == target_user.steam_uid
        end

        def dm_only?
          @limit_to == :dm
        end

        def text_only?
          @limit_to == :text
        end

        def dev_only?
          @requires.include?(:dev)
        end

        def registration_required?
          @requires.include?(:registration)
        end

        def whitelist_enabled?
          @whitelist_enabled || false
        end

        def on_cooldown?
          # We've never used this command with these arguments before
          return false if current_cooldown.nil?

          current_cooldown.active?
        end

        #
        # Makes calls to I18n.t shorter
        #
        def t(translation_name, **args)
          I18n.t("commands.#{name}.#{translation_name}", **args)
        end

        #
        # Returns the commands argument values
        #
        # @return [ESM::Command::ArgumentContainer] The commands arguments
        #
        def args
          @arguments
        end

        #
        # Builds a message and raises a CheckFailure with that reason.
        #
        # @param error_name [String, Symbol, nil] The name of the error message located in the locales for "commands.<command_name>.errors". If nil, a block must be provided
        # @param args [Hash] The args to be passed into the translation if an error_name is provided
        # @param block [Proc] If provided, the block must return the error message to be used. This can be a string or an ESM::Embed.
        #
        def raise_error!(error_name = nil, **args, &block)
          exception_class = args.delete(:exception_class)

          reason =
            if block
              yield
            else
              ESM::Embed.build(:error, description: I18n.t("commands.#{name}.errors.#{error_name}", **args))
            end

          # Logging
          ESM::Notifications.trigger("command_check_failed", command: self, reason: reason)

          raise exception_class || ESM::Exception::CheckFailure, reason
        end

        def skip(*flags)
          flags.each { |flag| @skip_flags << flag }
        end

        #
        # Sends a message to the target_server
        #
        # @param outgoing_message [ESM::Message, Hash] If a ESM::Message is provided, this message will be sent as is. If a Hash is provided, a message will be built from it
        # @param send_opts [Hash] Passed into #send_message. @see ESM::Connection::Server.fire
        # @return [ESM::Message] The message that was sent
        #
        def send_to_arma(outgoing_message = {}, send_opts = {})
          raise ESM::Exception::CheckFailure, "Command #{name} must define the `server_id` argument in order to use #send_to_arma" if target_server.nil?

          # Allows overwriting the outbound message. Otherwise, build a message from the data
          if outgoing_message.is_a?(Hash)
            # Allows providing `data: content` or,
            #                  `data: { type: :different }` or,
            #                  `data: { type: :different, content: different_content }`
            data = outgoing_message[:data] || {}
            unless data.key?(:type) && (data.key?(:content) || data.size == 1)
              outgoing_message[:data] = {
                type: name,
                content: outgoing_message[:data]
              }
            end

            outgoing_message[:type] = :arma unless outgoing_message.key?(:type)
            outgoing_message = ESM::Message.from_hash(outgoing_message)

            # This is how the message gets back to the command
            outgoing_message.add_callback(:on_response, on_instance: self) do |incoming_message|
              timers.time!(:on_response) do
                on_response(incoming_message, outgoing_message)
              end
            end
          end

          outgoing_message.add_attribute(:server_id, target_server.server_id)
          outgoing_message.add_attribute(:command, self)
          outgoing_message.apply_command_metadata

          target_server.send_message(outgoing_message, send_opts)
        end

        #
        # Shorthand method for sending a query message to Arma
        #
        # @param name [String, Symbol] The name of the query
        # @param **arguments [Hash] The query arguments
        #
        # @return [ESM::Message] The outbound message
        #
        def query_arma(name, **arguments)
          send_to_arma(
            type: :query,
            data: {
              type: :query,
              content: {
                name: name,
                arguments: arguments
              }
            }
          )
        end

        # Convenience method for replying back to the event's channel
        def reply(message)
          ESM.bot.deliver(message, to: current_channel, replying_to: @event&.message)
        end

        def edit_message(message, content)
          if content.is_a?(ESM::Embed)
            embed = Discordrb::Webhooks::Embed.new
            content.transfer(embed)

            message.edit("", embed)
          else
            message.edit(content)
          end
        end
      end
    end
  end
end
