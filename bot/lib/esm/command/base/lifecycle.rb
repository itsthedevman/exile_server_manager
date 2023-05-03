# frozen_string_literal: true

module ESM
  module Command
    class Base
      module Lifecycle
        # The entry point for a command
        # @note Do not handle exceptions anywhere in this commands lifecycle
        def execute(event, ...)
          if event.is_a?(Discordrb::Commands::CommandEvent)
            # The event has to be stored before argument parsing because of callbacks referencing event data
            self.event = event
            arguments.parse!(event)

            # V1
            command =
              if v2_target_server? || !self.class.has_v1_variant?
                self
              else
                "#{self.class}V1".constantize.new
              end

            command.send(:from_discord, event, arguments)
          else
            from_server(event)
          end
        rescue => e
          if command
            command.send(:handle_error, e, ...)
          else
            handle_error(e, ...)
          end
        end

        def from_discord(discord_event, arguments)
          self.event = discord_event
          self.executed_at = DateTime.now
          self.arguments = arguments
          permissions.load

          checks.text_only!
          checks.dm_only!
          checks.permissions!

          arguments.validate!

          ESM::Notifications.trigger("command_from_discord", command: self)
          checks.run_all!

          result = on_execute
          create_or_update_cooldown

          # This just tracks how many times a command is used
          ESM::CommandCount.increment_execution_counter(name)

          result
        end

        # @param request [ESM::Request] The request to build this command with
        # @note Don't load `target_user` from the request. If the arguments contain a target, it will handle it
        def from_request(request)
          @request = request

          # Initialize our command from the request
          @arguments.from_hash(request.command_arguments) if request.command_arguments.present?
          @current_channel = ESM.bot.channel(request.requested_from_channel_id)
          @current_user = request.requestor.discord_user

          if @request.accepted
            request_accepted
          else
            # Reset the cooldown since the request was declined.
            current_cooldown.reset! if current_cooldown.present?

            request_declined
          end
        end

        def on_response(_incoming_message, _outgoing_message)
        end

        def request_accepted
        end

        def request_declined
        end

        def request
          @request ||= lambda do
            requestee = target_user || current_user

            # Don't look for the requestor because multiple different people could attempt to invite them
            # requestor_user_id: current_user.esm_user.id,
            query = ESM::Request.where(requestee_user_id: requestee.esm_user.id, command_name: @name)

            @arguments.to_h.each do |name, value|
              query = query.where("command_arguments->>'#{name}' = ?", value)
            end

            query.first
          end.call
        end

        def add_request(to:, description: "")
          @request =
            ESM::Request.create!(
              requestor_user_id: current_user.esm_user.id,
              requestee_user_id: to.esm_user.id,
              requested_from_channel_id: current_channel.id.to_s,
              command_name: @name,
              command_arguments: @arguments.to_h
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
              e.add_field(name: I18n.t("commands.request.command_usage_name"), value: I18n.t("commands.request.command_usage_value", prefix: ESM.config.prefix, uuid: request.uuid_short))
            end

          ESM.bot.deliver(embed, to: target)
        end

        def create_or_update_cooldown
          return if skip_flags.include?(:cooldown)

          new_cooldown = current_cooldown_query.first_or_create
          new_cooldown.update_expiry!(@executed_at, @permissions.cooldown_time)

          @current_cooldown = new_cooldown
        end

        def current_cooldown_query
          query = ESM::Cooldown.where(command_name: name)

          # If the command requires a steam_uid, use it to track the cooldown.
          query =
            if registration_required?
              query.where(steam_uid: current_user.steam_uid)
            else
              query.where(user_id: current_user.esm_user.id)
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

        def handle_error(error, raise_error: ESM.env.test?)
          message = nil

          # So tests can check for errors
          raise error if raise_error

          case error
          when ESM::Exception::CheckFailure, ESM::Exception::FailedArgumentParse
            message = error.data
          when ESM::Exception::CheckFailureNoMessage
            return
          when StandardError
            uuid = SecureRandom.uuid
            ESM.logger.error("#{self.class}##{__method__}") { ESM::JSON.pretty_generate(uuid: uuid, message: error.message, backtrace: error.backtrace) }

            message = ESM::Embed.build(:error, description: I18n.t("exceptions.system", error_code: uuid))
          end

          ESM.bot.deliver(message, to: @event&.channel)
        end
      end
    end
  end
end
