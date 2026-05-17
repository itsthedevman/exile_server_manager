# frozen_string_literal: true

# Test-mode overrides for ESM::Discord::Bot:
#
#   - #run becomes a no-op that flips ready status without opening a gateway
#     connection or binding events.
#   - cache_*  helpers inject hand-rolled Discordrb objects into the bot's
#     internal caches so #user, #server, #channel, #pm_channel resolve them
#     without an HTTP fallback.
#   - #snapshot / #restore lets around(:each) roll back per-test factory
#     additions while keeping any baseline state.
module ESM
  module Discord
    class Bot
      #
      # Test override of `ESM::Discord::Bot#run`. Mirrors the production esm_ready hook minus
      # anything that requires a live Discord gateway: command hook setup, V1 websocket server,
      # V2 connection server.
      #
      # Note: `ESM::Request::Overseer.watch` is intentionally NOT started. In production it
      # spawns a TimerTask that polls expired Request rows; in tests it races with
      # DatabaseCleaner truncations and trips on nil PG connections. Specs that need
      # expiration behavior should drive it manually.
      #
      # @param async [Boolean] kept for signature compatibility; ignored
      # @param skip_initialization [Boolean] kept for signature compatibility; ignored
      #
      # @return [true] when ready (or already ready)
      #
      def run(async: false, skip_initialization: false)
        return if @esm_status == :ready

        ESM::Command.setup_event_hooks!
        @esm_status = :ready

        ESM::Websocket.start!
        ESM::Arma::Server.start
        true
      end

      #
      # Always true in tests. There's no real gateway connection, but lib/ and specs that gate on
      # `connected?` should proceed.
      #
      # @return [true]
      #
      def connected?
        true
      end

      #
      # Test override of `ESM::Discord::Bot#stop`. Tears down V1 / V2 services like production, but
      # skips the gateway-close cascade because there is no live gateway to close.
      # `Discordrb::Gateway#close` would try to send a websocket frame and raise.
      #
      def stop
        ESM::Websocket::Server.stop
        ESM::Request::Overseer.die
        ESM::Arma::Server.stop if defined?(ESM::Arma::Server)
        @esm_status = :stopped
      end

      #
      # Always true in tests. The production check resolves the bot's Member
      # on the channel's server and tests for the permission bit; with no
      # gateway there's no bot profile, so all permission checks pass.
      # Specs that want to assert permission denial should stub this method.
      #
      # @return [true]
      #
      def channel_permission?(_permission, _channel)
        true
      end

      #
      # Lazily-built {Spec::Inbox} that backs the test-mode `await!` /
      # `add_await!` overrides. Specs queue replies through this and lib/
      # code consumes them as if Discord had delivered the message.
      #
      # @return [Spec::Inbox]
      #
      def test_inbox
        @test_inbox ||= Spec::Inbox.new
      end

      #
      # Lazily-built {Spec::Outbox} that backs the Discordrb::Channel
      # send_message / send_embed extension. Replaces `ESM::Test.messages`,
      # mirroring `test_inbox` to make the producer/consumer relationship clear.
      #
      # @return [Spec::Outbox]
      #
      def test_outbox
        @test_outbox ||= Spec::Outbox.new
      end

      #
      # Test override of `Discordrb::Cache#user`. Cache-only. Never falls back to the Discord REST
      # API. A miss returns `nil` instead of logging an "Unknown User" error from a doomed HTTP
      # fetch.
      #
      # @param id [Integer, String] user ID
      #
      # @return [Discordrb::User, nil]
      #
      def user(id)
        @users[id.to_i]
      end

      #
      # Test override of `Discordrb::Cache#server`. Cache-only. Never falls back to the Discord REST
      # API. A miss returns `nil` instead of logging an "Unknown Guild" error from a doomed HTTP
      # fetch.
      #
      # @param id [Integer, String] server (guild) ID
      #
      # @return [Discordrb::Server, nil]
      #
      def server(id)
        @servers[id.to_i]
      end

      #
      # Test override of `Discordrb::Cache#channel`. Cache-only. Never falls back to the Discord
      # REST API. A miss returns `nil`.
      #
      # @param id [Integer, String] channel ID
      # @param _server [Discordrb::Server, nil] kept for signature compat
      #
      # @return [Discordrb::Channel, nil]
      #
      def channel(id, _server = nil)
        @channels[id.to_i]
      end

      #
      # Test override of `Discordrb::Cache#member`. Cache-only. Never falls back to the Discord
      # REST API. The default implementation would HTTP-fetch on a miss and log "Unknown User"; we
      # resolve from the server's local member cache or return `nil`.
      #
      # @param server_or_id [Discordrb::Server, Integer, String]
      # @param user_id [Integer, String]
      #
      # @return [Discordrb::Member, nil]
      #
      def member(server_or_id, user_id)
        target_server = server_or_id.is_a?(Discordrb::Server) ? server_or_id : server(server_or_id)
        return nil if target_server.nil?
        return nil unless target_server.member_cached?(user_id.to_i)

        target_server.member(user_id.to_i)
      end

      #
      # Inject a `Discordrb::User` into the bot's user cache so `bot.user(id)`
      # resolves it without an HTTP fallback.
      #
      # @param user [Discordrb::User]
      #
      def cache_user(user)
        @users[user.id] = user
      end

      #
      # Inject a `Discordrb::Server` into the server cache and add each of
      # its channels to the channel cache.
      #
      # @param server [Discordrb::Server]
      #
      # @return [Discordrb::Server] the server, for chaining
      #
      def cache_server(server)
        @servers[server.id] = server
        server.channels.each { |channel| @channels[channel.id] = channel }
        server
      end

      #
      # Inject a `Discordrb::Channel` into the channel cache.
      #
      # @param channel [Discordrb::Channel]
      #
      def cache_channel(channel)
        @channels[channel.id] = channel
      end

      #
      # Associate a DM channel with a user ID so `bot.pm_channel(user_id)`
      # returns the given channel instead of building a new one.
      #
      # @param user_id [Integer, String]
      # @param channel [Discordrb::Channel]
      #
      def cache_pm_channel(user_id, channel)
        @pm_channels[user_id.to_i] = channel
      end

      #
      # Test override of `Discordrb::Cache#pm_channel`. In production this
      # opens a real DM channel via the Discord API; here we lazily build an
      # in-memory `Discordrb::Channel` of type 1 (DM).
      #
      # The channel is also registered in `@channels` so `bot.channel(id)` resolves it.
      # Application-command events look channels up via the general channel cache, not the
      # pm-specific one.
      #
      # @param user_id [Integer, String] the user the DM is with
      #
      # @return [Discordrb::Channel] type-1 channel, cached for next call
      #
      def pm_channel(user_id)
        user_id = user_id.to_i
        @pm_channels[user_id] ||= begin
          channel = Discordrb::Channel.new(
            {
              "id" => Spec::Snowflake.next,
              "type" => 1,
              "recipients" => [{"id" => user_id.to_s, "username" => @users[user_id]&.username || "unknown"}]
            },
            self
          )
          @channels[channel.id] = channel
          channel
        end
      end

      #
      # Snapshot the bot's caches so they can be restored after a test.
      # Used by the around(:each) hook to roll back per-test factory
      # additions while keeping any baseline world.
      #
      # @return [Hash{Symbol => Hash}]
      #
      def snapshot
        {
          users: @users.dup,
          servers: @servers.dup,
          channels: @channels.dup,
          pm_channels: @pm_channels.dup
        }
      end

      #
      # Restore the cache state captured by {#snapshot}.
      #
      # @param snapshot [Hash{Symbol => Hash}] the value previously returned
      #   by {#snapshot}
      #
      def restore(snapshot)
        @users = snapshot[:users].dup
        @servers = snapshot[:servers].dup
        @channels = snapshot[:channels].dup
        @pm_channels = snapshot[:pm_channels].dup
      end
    end
  end
end
