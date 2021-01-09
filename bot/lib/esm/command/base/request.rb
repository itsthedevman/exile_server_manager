# frozen_string_literal: true

module ESM
  module Command
    class Base
      module Request
        # @param request [ESM::Request] The request to build this command with
        # @param accepted [Boolean] If the request was accepted (true) or denied (false)
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
              command_name: @name.underscore,
              command_arguments: @arguments.to_h
            )

          send_request_message(description: description, target: to)
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

        def send_request_message(description: "", target:)
          embed =
            ESM::Embed.build do |e|
              e.set_author(name: current_user.distinct, icon_url: current_user.avatar_url)
              e.description = description
              e.add_field(name: I18n.t("commands.request.accept_name"), value: I18n.t("commands.request.accept_value", url: accept_request_url), inline: true)
              e.add_field(name: I18n.t("commands.request.decline_name"), value: I18n.t("commands.request.decline_value", url: decline_request_url), inline: true)
              e.add_field(name: I18n.t("commands.request.command_usage_name"), value: I18n.t("commands.request.command_usage_value", prefix: ESM.config.prefix, uuid: request.uuid_short))
            end

          ESM.bot.deliver(embed, to: target)
        end
      end
    end
  end
end
