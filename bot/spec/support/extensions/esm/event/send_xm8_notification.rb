# frozen_string_literal: true

# Test override of `ESM::Event::SendXm8Notification::NotificationManager`. In
# production it owns a `Concurrent::TimerTask` that polls a `Queue` every
# second and processes notifications inside `ESM::Database.with_connection`.
# In tests, that background thread races with DatabaseCleaner: when an
# example finishes with notifications still in flight, the next tick fires
# during `delete_table` and PG returns a nil result mid-DELETE
# (`undefined method 'cmd_tuples' for nil`).
#
# The override drops the TimerTask entirely and processes notifications
# synchronously when `add` is called. Specs that previously waited on the
# async manager see the same effects, just sooner.
module ESM
  module Event
    class SendXm8Notification
      class NotificationManager
        def initialize(execution_interval: 1)
          @queue = Queue.new
        end

        def add(notifications)
          notifications.each do |notification|
            @queue.push(notification)
            ESM::Database.with_connection { notification.send_to_recipients }
          end
        end
      end
    end
  end
end
