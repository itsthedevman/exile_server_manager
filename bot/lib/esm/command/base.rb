# frozen_string_literal: true

require "esm/command/base/check_methods"
require "esm/command/base/error_message"
require "esm/command/base/logging_methods"
require "esm/command/base/permission_methods"

# The main driver for all of ESM's commands. This class is synomysis with ActiveRecord::Base in that all commands inherit
# from this class and this class gives access to a lot of the core functionality.
module ESM
  module Command
    class Base
      include PermissionMethods
      include CheckMethods
      include LoggingMethods

      def self.error_message(name, **args)
        if args.blank?
          ESM::Command::Base::ErrorMessage.send(name)
        else
          ESM::Command::Base::ErrorMessage.send(name, args)
        end
      end

      # The lengths I had to go to get this to work. It's either that this was really hard, or I'm literally stupid.
      # I **could not** find a way to get an inherited method to be able to call a method defined on an overridden module.
      # This is so we can override module ErrorMessage in a command class and be
      #   able to access it in that class by calling `error_message` (without having to define it in that class or include it. mwahaha)
      def self.inherited(child_class)
        child_class.send(:define_method, :error_message) do |name, **args|
          klass = "#{child_class}::ErrorMessage".constantize

          if args.blank?
            klass.send(name)
          else
            klass.send(name, args)
          end
        end

        child_class.reset_variables!
      end

      def self.reset_variables!
        @aliases = []
        @arguments = ESM::Command::ArgumentContainer.new
        @type = nil
        @limit_to = nil
        @defines = OpenStruct.new
        @requires = []
        @skipped_checks = Set.new

        # ESM::Command::Development::Eval => eval
        @name = self.name.demodulize.downcase
      end

      def self.aliases(*aliases)
        @aliases = aliases
      end

      def self.argument(name, opts = {})
        @arguments << ESM::Command::Argument.new(name, opts)
      end

      # rubocop:disable Style/TrivialAccessors
      def self.type(type)
        @type = type
      end

      def self.limit_to(channel_type)
        @limit_to = channel_type
      end
      # rubocop:enable Style/TrivialAccessors

      def self.define(attribute, **opts)
        @defines[attribute] = OpenStruct.new(opts)
      end

      def self.requires(*keys)
        @requires = keys
      end

      def self.attributes
        @attributes ||=
          OpenStruct.new(
            name: @name,
            aliases: @aliases,
            arguments: @arguments,
            type: @type,
            limit_to: @limit_to,
            defines: @defines,
            requires: @requires,
            skipped_checks: @skipped_checks
          )
      end

      def self.skip_check(*checks)
        checks.each do |check|
          @skipped_checks << check
        end
      end

      #########################
      # Public Instance Methods
      #########################
      attr_reader :name, :category, :type, :example, :arguments,
                  :description, :aliases, :offset, :distinct, :limit_to,
                  :defines, :requires, :executed_at, :response, :cooldown_time

      attr_writer :limit_to, :event, :executed_at, :requires if ESM.env.test?

      def initialize
        attributes = self.class.attributes

        @name = attributes.name

        # Attempt to pull the description and examples from translation. Default to empty
        @description = t("commands.#{@name}.description", default: "")
        @example = t("commands.#{@name}.example", default: "")

        # ESM::Command::Development => Development (God I love ActiveSupport)
        @category = self.class.module_parent.name.demodulize
        @distinct = "#{ESM.config.prefix}#{@name}"
        @offset = @distinct.size
        @aliases = attributes.aliases
        @arguments = attributes.arguments
        @type = attributes.type
        @limit_to = attributes.limit_to
        @defines = attributes.defines
        @requires = attributes.requires

        # Flags for skipping check_for_x! methods
        @skipped_checks = attributes.skipped_checks

        # Flags for skipping anything else
        @skip_flags = Set.new

        # Store the command on the arguments, so we can access for error reporting
        @arguments.command = self
      end

      def execute(event)
        if event.is_a?(Discordrb::Commands::CommandEvent)
          from_discord(event)
        else
          from_server(event)
        end
      end

      def usage
        @usage ||= "#{@distinct} #{@arguments.map(&:to_s).join(" ")}"
      end

      # The user that executed the command
      def current_user
        @current_user ||= ESM::User.parse(@event.user&.id)
      end

      # @returns [ESM::Community, nil] The community the command was executed from. Nil if sent from Direct Message
      def current_community
        @current_community ||= ESM::Community.find_by_guild_id(@event.server&.id)
      end

      # @returns [ESM::Cooldown] The cooldown for this command and user
      def current_cooldown
        @current_cooldown ||= load_current_cooldown
      end

      # @returns [ESM::Server, nil] The server that the command was executed for
      def target_server
        return nil if @arguments.server_id.blank?

        @target_server ||= ESM::Server.find_by_server_id(@arguments.server_id)
      end

      # @returns [ESM::Community, nil] The community that the command was executed for
      def target_community
        @target_community ||= lambda do
          return ESM::Community.find_by_community_id(@arguments.community_id) if @arguments.community_id

          # If we have a server ID, we can extract the community ID from it
          ESM::Community.find_by_server_id(@arguments.server_id) if @arguments.server_id
        end.call
      end

      # @returns [ESM::User, nil] The user that the command was executed against
      def target_user
        @target_user ||= ESM::User.parse(@arguments.target)
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

      def next_expiry
        return @executed_at if @cooldown_time.nil?
        return @next_expiry if @next_expiry

        @next_expiry ||= @executed_at + @cooldown_time
      end

      def on_cooldown?
        # We've never used this command with these arguments before
        return false if current_cooldown.nil?

        current_cooldown.active?
      end

      def deliver!(**parameters)
        raise ESM::Exception::CheckFailure, "Command does not have an associated server" if target_server.nil?

        ESM::Websocket.deliver!(
          target_server.server_id,
          command: self,
          user: current_user,
          parameters: parameters,
          channel: @event.channel
        )
      end

      # Convenience method for replying back to the event's channel
      def reply(message)
        ESM.bot.deliver(message, to: @event.channel)
      end

      private

      def from_discord(event)
        @event = event
        @executed_at = DateTime.now

        # Parse arguments or raises FailedArgumentParse
        @arguments.parse!(@event)

        # Create the user in our DB if we have never seen them before
        create_user if current_user.esm_user.nil?

        # Run some checks
        check_for_all_of_the_checks!

        # Logging
        log_from_discord_event

        # Call the discord method
        response = discord

        # Update the cooldown
        create_or_update_cooldown if !@skip_flags.include?(:cooldown)

        # Return the response
        response
      end

      def from_server(parameters)
        # Parameters is always an array. 90% of the time, parameters size will only be 1
        # This just makes typing a little easier when writing commands
        @response = parameters.size == 1 ? parameters.first : parameters

        # Logging
        log_from_server_event

        # Call the server method
        server
      end

      def create_user
        user = ESM::User.create!(
          discord_id: current_user.id,
          discord_username: current_user.name,
          discord_discriminator: current_user.discriminator
        )

        # Set the database ID since DiscordRB will cache this
        current_user.esm_user = user
      end

      def create_or_update_cooldown
        query = ESM::Cooldown.where(command_name: @name, user_id: current_user.esm_user.id)
        query.where(community_id: target_community.id) if target_community
        query.where(server_id: target_server.id) if target_server

        new_cooldown = query.first_or_create
        new_cooldown.update!(expires_at: next_expiry)

        @current_cooldown = new_cooldown
      end

      def load_current_cooldown
        query = ESM::Cooldown.where(command_name: @name, user_id: current_user.esm_user.id)

        # check for the community
        query.where(community_id: target_community.id) if target_community

        # Check for the individual server
        query.where(server_id: target_server.id) if target_server

        # Fire the query and return the first result
        query.first
      end

      def load_permissions
        community = target_community || current_community
        config =
          if community.present?
            CommandConfiguration.where(community_id: community.id, command_name: self.name).first
          else
            nil
          end

        config_present = config.present?

        @enabled =
          if config_present
            config.enabled?
          else
            @defines.enabled.default
          end

        @allowed =
          if config_present
            config.allowed_in_text_channels?
          else
            @defines.allowed_in_text_channels.default
          end

        @whitelist_enabled =
          if config_present
            config.whitelist_enabled?
          else
            @defines.whitelist_enabled.default
          end

        @whitelisted_role_ids =
          if config_present
            config.whitelisted_role_ids
          else
            @defines.whitelisted_role_ids.default
          end

        @cooldown_time =
          if config_present
            # [2, "seconds"] -> 2 seconds
            config.cooldown_quantity.send(config.cooldown_type)
          else
            @defines.cooldown_time.default
          end
      end

      def skip(*flags)
        flags.each { |flag| @skip_flags << flag }
      end
    end
  end
end
