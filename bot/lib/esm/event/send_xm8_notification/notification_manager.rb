# frozen_string_literal: true

module ESM
  module Event
    class SendXm8Notification
      class NotificationManager
        attr_reader :queue

        def initialize(execution_interval: 1)
          @queue = Queue.new

          @task = Concurrent::TimerTask.execute(execution_interval:) { process_next }
          @task.add_observer(ErrorHandler.new)
        end

        def add(notifications)
          notifications.each { |n| queue.push(n) }
        end

        private

        def process_next
          notification = queue.pop(timeout: 0)
          return if notification.nil?

          ESM::Database.with_connection { notification.send_to_recipients }
        end
      end
    end
  end
end
