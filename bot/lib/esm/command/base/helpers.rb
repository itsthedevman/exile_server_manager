# frozen_string_literal: true

module ESM
  module Command
    class Base
      module Helpers
        extend ActiveSupport::Concern

        class_methods do
          #
          # Returns the command's execution string, with or without arguments.
          #   /command subcommand argument_1:value argument_2: value
          #
          # @param overrides [Hash] Argument names and values to set.
          #   These will override the default arguments. Ignored if with_args is false
          #
          # @param use_placeholders [true/false] Controls if a placeholder is used as the arguments value
          #   If true, and the argument is blank, the argument's name will be used as a placeholder
          #   If false, and the argument is blank, the argument is omitted from the result
          #
          # @param with_args [true/false] Should the arguments be included in result?
          # @param with_slash [true/false] Should the result start with a slash?
          # @param skip_defaults [true/false] Skip displaying arguments that are using their default value?
          #
          # @return [String]
          #
          def usage(arguments: {}, use_placeholders: true, with_args: true, with_slash: true, skip_defaults: true)
            command_statement = namespace[:segments].dup
            command_statement << namespace[:command_name]

            if with_args && self.arguments.size > 0
              self.arguments.each do |(name, template)|
                # Better support for falsey values
                value =
                  if arguments.key?(name)
                    arguments[name]
                  elsif arguments.key?(template.display_name)
                    arguments[template.display_name]
                  end

                # Perf
                value_is_blank = value.blank?

                next if value_is_blank && template.optional?
                next if value_is_blank && !use_placeholders
                next if skip_defaults && template.default_value? && template.default_value == value

                command_statement << (value_is_blank ? "#{template}:<#{template.placeholder}>" : "#{template}:#{value}")
              end
            end

            command_statement = command_statement.join(" ")
            command_statement.prepend("/") if with_slash
            command_statement
          end
        end

        #
        # See class method .usage above
        #
        def usage(**args)
          args[:use_placeholders] ||= false
          args[:arguments] = arguments.merge(args[:arguments] || {})

          self.class.usage(**args)
        end

        #
        # The cooldown for this command
        #
        # @return [ESM::Cooldown]
        #
        def current_cooldown
          @current_cooldown ||= current_cooldown_query.first
        end

        #
        # The ESM representation of a community's Arma 3 Server
        #
        # @return [ESM::Server, nil] The server that the command was executed for
        #
        def target_server
          @target_server ||= lambda do
            return unless arguments.server_id

            ESM::Server.find_by_server_id(arguments.server_id)
          end.call
        end

        #
        # The ESM representation of a Discord server that is the target of this command
        #
        # @return [ESM::Community, nil] The community that the command was executed for
        #
        def target_community
          @target_community ||= lambda do
            return ESM::Community.find_by_community_id(arguments.community_id) if arguments.community_id

            target_server&.community
          end.call
        end

        #
        # The ESM representation of a Discord user that is the target of this command
        # This method is expected to only execute the code once.
        # This avoids sending invalid IDs to Discord over and over again
        #
        # @return [ESM::User, ESM::User::Ephemeral, nil] The user that the command was executed against
        #
        def target_user
          @target_user ||= lambda do
            return if arguments.target.nil?

            # This could be a steam_uid, discord id, or mention
            # Automatically remove the mention characters
            target = arguments.target.gsub(/[<@!&>]/, "").strip

            # Attempt to find the target within ESM
            user = ESM::User.parse(target)

            # This validates that the user exists and we get a discord user back
            if (_discord_user = user&.discord_user)
              return user
            end

            # We didn't find a user and a steam uid can't be used to find a Discord user
            # Ephemeral user represents a user that doesn't have a ESM::User
            return ESM::User::Ephemeral.new(target) if target.steam_uid?

            # target is a discord ID and user is nil
            discord_user = ESM.bot.user(target) if target.match?(ESM::Regex::DISCORD_ID_ONLY)
            return ESM::User::Ephemeral.new(target) if discord_user.nil?

            ESM::User.from_discord(discord_user)
          end.call
        end

        #
        # Sometimes we're given a steam UID that may not be linked to a discord user
        # But, the command can work without the registered part.
        #
        # @return [String, nil] The steam uid from given argument or the steam uid registered to the target_user (which may be nil)
        #
        def target_uid
          return if arguments.target.nil?

          @target_uid ||= lambda do
            arguments.target.steam_uid? ? arguments.target : target_user&.steam_uid
          end.call
        end

        #
        # The community, in which this command is being executed, command permissions
        #
        # @return [ESM::CommandConfiguration, nil]
        #
        def community_permissions
          @community_permissions ||= lambda do
            community = target_community || current_community
            return unless community

            community.command_configurations.where(command_name: command_name).first
          end.call
        end

        #
        # Is the current_user also the target_user?
        #
        # @return [Boolean]
        #
        def same_user?
          return false if target_user.nil?

          current_user.steam_uid == target_user.steam_uid
        end

        #
        # Is the command limited to Direct Messages?
        #
        # @return [Boolean]
        #
        def dm_only?
          limited_to == :dm
        end

        #
        # Is the command limited to text channels?
        #
        # @return [Boolean]
        #
        def text_only?
          limited_to == :text
        end

        #
        # Returns if the current channel is a text channel
        # @note Discordrb has helpers for this, but they're buggy?
        #
        # @return [<Type>] <description>
        #
        def text_channel?
          return false if current_channel.nil?

          current_channel.type == Discordrb::Channel::TYPES[:text]
        end

        #
        # Returns if the current channel is a direct message with the user
        # @note Discordrb has helpers for this, but they're buggy?
        #
        # @return [TrueClass, FalseClass]
        #
        def dm_channel?
          return false if current_channel.nil?

          current_channel.type == Discordrb::Channel::TYPES[:dm]
        end

        #
        # Is the command limited to developers only?
        #
        # @return [Boolean]
        #
        def dev_only?
          requirements.dev?
        end

        #
        # Does the command require registration?
        #
        # @return [Boolean]
        #
        def registration_required?
          requirements.registration?
        end

        #
        # Is this command on cooldown?
        #
        # @return [Boolean]
        #
        def on_cooldown?
          # We've never used this command with these arguments before
          return false if current_cooldown.nil?

          current_cooldown.active?
        end

        #
        # Makes calls to I18n.t shorter
        #
        def t(translation_name, **)
          I18n.t("commands.#{name}.#{translation_name}", **)
        end

        def argument?(argument_name)
          arguments.key?(argument_name) || arguments.display_name_mapping.key?(argument_name)
        end

        def to_h
          {
            name: name,
            arguments: arguments,
            current_community: current_community&.attributes,
            current_channel: current_channel&.attributes,
            current_user: current_user&.attributes,
            current_cooldown: current_cooldown&.attributes,
            target_community: target_community&.attributes,
            target_server: target_server&.attributes&.except("server_key"),
            target_user: target_user&.attributes,
            target_uid: target_uid,
            same_user: same_user?,
            dm_only: dm_only?,
            text_only: text_only?,
            dev_only: dev_only?,
            registration_required: registration_required?,
            on_cooldown: on_cooldown?,
            skipped_actions: skipped_actions.to_h,
            permissions: {
              config: community_permissions&.attributes,
              allowlist_enabled: command_allowlist_enabled?,
              enabled: command_enabled?,
              allowed: command_allowed_in_channel?,
              allowlisted: command_allowed?,
              notify_when_disabled: notify_when_command_disabled?,
              cooldown_time: cooldown_time
            }
          }
        end

        def inspect
          "<#{self.class.name}, arguments: #{arguments}>"
        end

        #
        # Builds a message and raises a CheckFailure with that reason.
        #
        # @param error_name [String, Symbol, nil] The name of the error message located in the locales for "commands.<command_name>.errors". If nil, a block must be provided
        # @param args [Hash] The args to be passed into the translation if an error_name is provided
        # @param block [Proc] If provided, the block must return the error message to be used. This can be a string or an ESM::Embed.
        #
        def raise_error!(error_name = nil, **args, &block)
          exception_class = args.delete(:exception_class) || ESM::Exception::CheckFailure
          path_prefix = args.delete(:path_prefix) || "commands.#{name}.errors"

          reason =
            if block
              yield
            elsif error_name
              ESM::Embed.build(:error, description: I18n.t("#{path_prefix}.#{error_name}", **args))
            end

          warn!(
            exception_class: exception_class,
            author: "#{current_user.distinct} (#{current_user.discord_id})",
            channel: "#{Discordrb::Channel::TYPE_NAMES[current_channel.type]} (#{current_channel.id})",
            reason: reason.is_a?(Embed) ? reason.description : reason,
            command: to_h
          )

          raise exception_class, reason
        end

        def skip_action(*)
          skipped_actions.set(*)
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
          pending_delivery = ESM.bot.deliver(message, to: current_channel, async: false)
          pending_delivery.wait_for_delivery
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

        def request
          @request ||= lambda do
            requestee = target_user || current_user

            # Don't look for the requestor because multiple different people could attempt to invite them
            # requestor_user_id: current_user.esm_user.id,
            query = ESM::Request.where(requestee_user_id: requestee.id, command_name: command_name)

            arguments.to_h.each do |name, value|
              query = query.where("command_arguments->>'#{name}' = ?", value)
            end

            query.first
          end.call
        end

        def add_request(to:, description: "")
          @request =
            ESM::Request.create!(
              requestor_user_id: current_user.id,
              requestee_user_id: to.id,
              requested_from_channel_id: current_channel.id.to_s,
              command_name: command_name,
              command_arguments: arguments.to_h
            )

          send_request_message(description: description, target: to)
        end

        def request_url
          # I have no idea why the ENV won't apply for this _one_ key.
          if ESM.env.production?
            "https://www.esmbot.com/requests"
          else
            ENV["REQUEST_URL"]
          end
        end

        def accept_request_url(uuid)
          "#{request_url}/#{uuid}/accept"
        end

        def decline_request_url(uuid)
          "#{request_url}/#{uuid}/decline"
        end

        def send_request_message(target:, description: "")
          embed =
            ESM::Embed.build do |e|
              e.set_author(name: current_user.distinct, icon_url: current_user.avatar_url)
              e.description = description
              e.add_field(name: I18n.t("commands.request.accept_name"), value: I18n.t("commands.request.accept_value", url: accept_request_url(request.uuid)), inline: true)
              e.add_field(name: I18n.t("commands.request.decline_name"), value: I18n.t("commands.request.decline_value", url: decline_request_url(request.uuid)), inline: true)
              e.add_field(name: I18n.t("commands.request.command_usage_name"), value: I18n.t("commands.request.command_usage_value", uuid: request.uuid_short))
            end

          ESM.bot.deliver(embed, to: target)
        end

        def create_or_update_cooldown
          @current_cooldown = current_cooldown_query.first_or_create
          current_cooldown.update_expiry!(timers.on_execute.started_at, cooldown_time)
        end

        def current_cooldown_query
          query = ESM::Cooldown.where(command_name: command_name)

          # If the command requires a steam_uid, use it to track the cooldown.
          query =
            if registration_required?
              query.where(steam_uid: current_user.steam_uid)
            else
              query.where(user_id: current_user.id)
            end

          # Check for the target_community
          query = query.where(community_id: target_community.id) if target_community

          # If we don't have a target_community, use the current_community (if applicable)
          query = query.where(community_id: current_community.id) if current_community && target_community.nil?

          # Check for the individual server
          query = query.where(server_id: target_server.id) if target_server

          # Return the query
          query
        end
      end
    end
  end
end
