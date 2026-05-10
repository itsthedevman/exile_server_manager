# frozen_string_literal: true

# Production `Connection::Client#close` shuts down `@task` (the TimerTask that
# polls the socket for new messages) but leaves `@thread_pool` alive — the
# CachedThreadPool that processes those messages via
# `ESM::Database.with_connection { process_message }`. Workers already posted
# to the pool keep running, doing AR work, on a separate connection.
#
# In production this is fine; the pool drains naturally and gets GC'd. In
# tests it races with DatabaseCleaner's deletion: the worker's connection
# state and the spec thread's connection state collide on the wire (PG logs
# `message type X arrived from server while idle` and `WARNING: there is no
# transaction in progress`, then the cleanup transaction's COMMIT returns nil
# → `undefined method 'cmd_tuples' for nil`).
#
# This override defers to the production `close` (which now correctly handles
# a nil server model after the on_disconnect fix) and then waits for the
# thread pool to drain before returning, so by the time
# `Connection::Server.pause`'s `disconnect_all` finishes there is no
# in-flight AR work left to race with DatabaseCleaner.
module ESM
  module Connection
    class Client
      alias_method :__original_close, :close

      def close(reason = "")
        __original_close(reason)
      ensure
        @thread_pool&.shutdown
        # 1s is plenty for an in-flight worker to finish its AR query;
        # a longer wait holds disconnect_all and starves the retry loop
        # in spec_context/connection.rb.
        @thread_pool&.wait_for_termination(1)
      end
    end
  end
end
