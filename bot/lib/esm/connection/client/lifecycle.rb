# frozen_string_literal: true

module ESM
  module Connection
    class Client
      module Lifecycle
        VALID_REQUEST_TYPES = %w[
          send_to_channel
          send_xm8_notification
        ]

        private

        def on_message
          request = read
          return if request.nil?

          @thread_pool.post do
            ESM::Database.with_connection do
              process_message(request)
            end
          end
        end

        def process_message(request)
          if @ledger.include?(request)
            forward_to_caller(request)
            return
          end

          case request.type
          when :identification
            on_identification(request.content)
          when :message
            on_request(request.content)
          end
        rescue ESM::Exception::InvalidAccessKey
          close
        rescue ESM::Exception::ClosableError => e
          warn!(error: e)
          close
        rescue ESM::Exception::SendableError => e
          send_error(e.data)
        rescue => e
          error!(error: e)
        ensure
          @ledger.remove(request)
        end

        def forward_to_caller(request)
          promise = @ledger.remove(request)
          raise ESM::Exception::InvalidMessage if promise.nil?

          promise.set_response(request)
        end

        def on_identification(public_id)
          info!(address:, state: :on_identification, public_id:)

          existing_connection = ESM.connection_server.client(public_id)
          raise ESM::Exception::ExistingConnection if existing_connection

          model = ESM::Server.find_by_public_id(public_id)
          raise ESM::Exception::InvalidAccessKey if model.nil?

          authenticate!(model)
          initialize!(model)
        end

        def authenticate!(model)
          @public_id = model.public_id
          @server_id = model.server_id
          @session_id = SecureRandom.uuid

          secret_key = model.server_key

          # Do not set the session ID on this
          @encryption = Encryption.new(secret_key)

          # Generate new nonce indices for the client
          nonce_indices = Encryption.generate_nonce_indices

          message = ESM::Message.new
            .set_type(:init)
            .set_data(indices: nonce_indices, session_id:)

          # This doesn't use #send_request because it needs to hook into the promise to immediately
          # swap the nonce to the new one before the client has time to respond.
          # Ignorance is bliss but this shouldn't be a race condition due to network lag
          # "It works on my computer"
          response = write(id: message.id, type: :handshake, content: message.to_s)
            .then { |_| @encryption = Encryption.new(secret_key, nonce_indices:, session_id:) }
            .wait_for_response(@config.response_timeout)

          raise ESM::Exception::RejectedPromise, response.reason if response.rejected?

          # Ledger doesn't care what object it is, so long as it responds to #id
          @ledger.remove(message)
          nil
        end

        def initialize!(model)
          message = send_request(type: :initialize)
          ESM::Event::ServerInitialization.new(self, model, message).run!

          ESM.connection_server.on_initialize(self)
        end

        def check_for_valid_request!(message)
          return if message.type == :call &&
            VALID_REQUEST_TYPES.include?(message.data.function_name)

          raise ESM::Exception::InvalidRequest, "Invalid request received. Read the docs!"
        end

        def on_disconnect(reason = "")
          return if @public_id.nil?

          model = ESM::Server.find_by_public_id(@public_id)
          uptime = model.uptime

          model.update(server_start_time: nil, disconnected_at: ESM::Time.now)

          reason =
            if reason.present?
              reason
            elsif ESM.bot.stopping?
              I18n.t("server_disconnect.reasons.restart")
            else
              I18n.t("server_disconnect.reasons.normal")
            end

          info!(public_id:, server_id:, uptime:, reason:)

          message = I18n.t("server_disconnect.base", server: server_id, uptime:, reason:)
          model.community.log_event(:reconnect, message)
        end

        def on_request(content)
          message = ESM::Message.from_string(content)
          info!(address:, public_id:, server_id:, inbound: message.to_h)

          check_for_valid_request!(message)

          model = ESM::Server.find_by_public_id(@public_id)

          event_class =
            case message.data.function_name
            when "send_to_channel"
              Event::SendToChannel
            when "send_xm8_notification"
              Event::SendXm8Notification
            end

          event_class.new(model, message).run!
        end
      end
    end
  end
end
