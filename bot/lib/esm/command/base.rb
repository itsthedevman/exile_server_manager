# frozen_string_literal: true

# The main driver for all of ESM's commands. This class is synomysis with ActiveRecord::Base in that all commands inherit
# from this class and this class gives access to a lot of the core functionality.
module ESM
  module Command
    class Base
      class << self
        attr_reader :defines, :command_type, :category, :command_aliases
      end

      def self.name
        return @command_name if !@command_name.nil?

        super
      end

      def self.inherited(child_class)
        child_class.reset_variables!
      end

      def self.reset_variables!
        @command_aliases = []
        @arguments = ESM::Command::ArgumentContainer.new
        @type = nil
        @limit_to = nil
        @defines = OpenStruct.new
        @requires = []
        @skipped_checks = Set.new

        # ESM::Command::System::Accept => system
        @category = self.module_parent.name.demodulize.downcase

        # ESM::Command::Server::SetId => set_id
        @command_name = self.name.demodulize.underscore.downcase
      end

      def self.argument(name, opts = {})
        @arguments << ESM::Command::Argument.new(name, opts)
      end

      def self.example(prefix = ESM.config.prefix)
        I18n.t("commands.#{@command_name}.example", prefix: prefix, default: "")
      end

      def self.description(prefix = ESM.config.prefix)
        I18n.t("commands.#{@command_name}.description", prefix: prefix, default: "")
      end

      # I wanted these as methods instead of attributes
      #
      # rubocop:disable Style/TrivialAccessors
      def self.aliases(*aliases)
        @command_aliases = aliases
      end

      def self.type(type)
        @command_type = type
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
            name: @command_name,
            category: @category,
            aliases: @command_aliases,
            arguments: @arguments,
            type: @command_type,
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
      attr_reader :name, :category, :type, :arguments, :aliases, :limit_to,
                  :defines, :requires, :executed_at, :response, :cooldown_time,
                  :event, :permissions, :checks

      attr_writer :limit_to, :event, :executed_at, :requires if ESM.env.test?
      attr_writer :current_community

      def initialize
        attributes = self.class.attributes

        @name = attributes.name
        @category = attributes.category
        @aliases = attributes.aliases
        @arguments = attributes.arguments
        @type = attributes.type
        @limit_to = attributes.limit_to
        @defines = attributes.defines
        @requires = attributes.requires

        # Flags for skipping anything else
        @skip_flags = Set.new

        # Store the command on the arguments, so we can access for error reporting
        @arguments.command = self

        # Pre load
        @permissions = Base::Permissions.new(self)
        @checks = Base::Checks.new(self, attributes.skipped_checks)
      end

      def execute(event)
        if event.is_a?(Discordrb::Commands::CommandEvent)
          from_discord(event)
        else
          from_server(event)
        end
      end

      def usage
        @usage ||= "#{distinct} #{@arguments.map(&:to_s).join(" ")}"
      end

      # Dont't memoize this, prefix can change based on when its called
      def distinct
        "#{prefix}#{@name}"
      end

      def offset
        distinct.size
      end

      def example
        I18n.t("commands.#{@name}.example", prefix: prefix, default: "")
      end

      def description
        I18n.t("commands.#{@name}.description", prefix: prefix, default: "")
      end

      def prefix
        return ESM.config.prefix if current_community&.command_prefix.nil?

        current_community.command_prefix
      end

      # The user that executed the command
      def current_user
        return @current_user if defined?(@current_user) && @current_user.present?
        return nil if @event.user.nil?

        user =
          ESM::User.where(discord_id: @event.user.id).first_or_create do |new_user|
            new_user.discord_id = @event.user.id
            new_user.discord_username = @event.user.name
            new_user.discord_discriminator = @event.user.discriminator
          end

        # Return back the modified discord user
        @current_user = user.discord_user
      end

      # @returns [ESM::Community, nil] The community the command was executed from. Nil if sent from Direct Message
      def current_community
        return @current_community if defined?(@current_community) && @current_community.present?
        return nil if @event&.server.nil?

        @current_community = ESM::Community.find_by_guild_id(@event.server.id)
      end

      # @returns [ESM::Cooldown] The cooldown for this command and user
      def current_cooldown
        @current_cooldown ||= load_current_cooldown
      end

      def current_channel
        @current_channel ||= @event.channel
      end

      # @returns [ESM::Server, nil] The server that the command was executed for
      def target_server
        return nil if @arguments.server_id.blank?

        @target_server ||= ESM::Server.find_by_server_id(@arguments.server_id)
      end

      # @returns [ESM::Community, nil] The community that the command was executed for
      def target_community
        @target_community ||= lambda do
          return ESM::Community.find_by_community_id(@arguments.community_id) if @arguments.community_id.present?

          # If we have a server ID, we can extract the community ID from it
          ESM::Community.find_by_server_id(@arguments.server_id) if @arguments.server_id.present?
        end.call
      end

      # @returns [ESM::User, nil] The user that the command was executed against
      def target_user
        @target_user ||= ESM::User.parse(@arguments.target)&.discord_user
      end

      # @returns [Boolean] If the current user is the target user.
      def same_user?
        return false if target_user.nil?

        current_user.id == target_user.id
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

      def next_expiry
        return @executed_at if @permissions.cooldown_time.nil?

        @next_expiry ||= @executed_at + @permissions.cooldown_time
      end

      def on_cooldown?
        # We've never used this command with these arguments before
        return false if current_cooldown.nil?

        current_cooldown.active?
      end

      # Send a request to the DLL
      #
      # @param command_name [String, nil] The name of the command to send to the DLL. Default: self.name
      def deliver!(command_name: nil, timeout: 30, **parameters)
        raise ESM::Exception::CheckFailure, "Command does not have an associated server" if target_server.nil?

        # Build the request
        request = ESM::Websocket::Request.new(
          command: self,
          command_name: command_name,
          user: current_user,
          channel: current_channel,
          parameters: parameters,
          timeout: timeout
        )

        # Send it to the dll
        ESM::Websocket.deliver!(target_server.server_id, request)
      end

      # Convenience method for replying back to the event's channel
      def reply(message)
        ESM.bot.deliver(message, to: current_channel)
      end

      # @param request [ESM::Request] The request to build this command with
      # @param accepted [Boolean] If the request was accepted (true) or denied (false)
      def from_request(request)
        @request = request

        # Initialize our command from the request
        @arguments.from_hash(request.command_arguments) if request.command_arguments.present?
        @current_user = ESM::User.parse(request.requestor.discord_id)&.discord_user
        @target_user = ESM::User.parse(request.requestee.discord_id)&.discord_user
        @current_channel = ESM.bot.channel(request.requested_from_channel_id)

        if @request.accepted
          request_accepted
        else
          request_declined
        end
      end

      def request
        @request ||= lambda do
          # Don't look for the requestor because multiple different people could attempt to invite them
          # requestor_user_id: current_user.esm_user.id,
          query = ESM::Request.where(requestee_user_id: target_user.esm_user.id, command_name: @name)

          @arguments.to_h.each do |name, value|
            query = query.where("command_arguments->>'#{name}' = ?", value)
          end

          query.first
        end.call
      end

      # Returns a valid command string for execution.
      #
      # @example No arguments
      #   ESM::Command::SomeCommand.statement -> "!somecommand"
      # @example With arguments !argumentcommand <argument_1> <argument_2>
      #   ESM::Command::ArgumentCommand.statement(argument_1: "foo", argument_2: "bar") -> !argumentcommand foo bar
      def statement(**flags)
        # Can't use distinct here - 2020-03-10
        command_statement = "#{prefix}#{flags[:_use_alias] || @name}"

        # !birb, !doggo, etc.
        return command_statement if @arguments.empty?

        # !whois <target> -> !whois #{flags[:target]} -> !whois 1234567890
        @arguments.map(&:name).each do |name|
          command_statement += " #{flags[name]}"
        end

        command_statement
      end

      # Raises an exception of the given class or ESM::Exception::CheckFailure.
      # If a block is given, the return of that block will be message to raise
      # Otherwise, it will build an error embed
      def check_failed!(name = nil, **args, &block)
        message =
          if block_given?
            yield
          else
            ESM::Embed.build(:error, description: I18n.t("command_errors.#{name}", args.except(:exception_class)))
          end

        raise args[:exception_class] || ESM::Exception::CheckFailure, message
      end

      private

      def discord; end

      def server; end

      def request_accepted; end

      def request_declined; end

      def from_discord(event)
        @event = event
        @executed_at = DateTime.now

        # Start typing. The bot will automatically stop after 5 seconds or when the next message sends
        @event.channel.start_typing if !ESM.env.test?

        # Parse arguments or raises FailedArgumentParse
        @arguments.parse!(@event)

        # Logging
        ActiveSupport::Notifications.instrument("command_from_discord.esm", command: self)

        # Run some checks
        @checks.run_all!

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
        ActiveSupport::Notifications.instrument("command_from_server.esm", command: self, response: @response)

        # Call the server method
        server
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

      def skip(*flags)
        flags.each { |flag| @skip_flags << flag }
      end

      def add_request
        @request =
          ESM::Request.create!(
            requestor_user_id: current_user.esm_user.id,
            requestee_user_id: target_user.esm_user.id,
            requested_from_channel_id: current_channel.id.to_s,
            command_name: @name.underscore,
            command_arguments: @arguments.to_h
          )
      end

      def request_url
        return nil if @request.nil?

        "#{ENV["REQUEST_URL"]}/#{@request.uuid}"
      end

      def accept_request_url
        "#{request_url}/accept"
      end

      def decline_request_url
        "#{request_url}/decline"
      end

      def send_request_message(description: "")
        embed =
          ESM::Embed.build do |e|
            e.set_author(name: current_user.distinct, icon_url: current_user.avatar_url)
            e.description = description
            e.add_field(name: I18n.t("commands.request.accept_name"), value: I18n.t("commands.request.accept_value", url: accept_request_url), inline: true)
            e.add_field(name: I18n.t("commands.request.decline_name"), value: I18n.t("commands.request.decline_value", url: decline_request_url), inline: true)
            e.add_field(name: I18n.t("commands.request.command_usage_name"), value: I18n.t("commands.request.command_usage_value", prefix: prefix, uuid: request.uuid_short))
          end

        ESM.bot.deliver(embed, to: target_user)
      end
    end
  end
end
