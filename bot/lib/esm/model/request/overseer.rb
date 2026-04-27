# frozen_string_literal: true

module ESM
  class Request
    class Overseer
      def self.watch
        execution_interval = ESM.config.request_overseer.check_every

        @task = Concurrent::TimerTask.execute(execution_interval:) do
          ESM::Database.with_connection do
            ESM::Request.expired.destroy_all
          end
        end

        @task.add_observer(ErrorHandler.new)
      end

      def self.die
        return if @task.nil?

        @task.shutdown
      end
    end
  end
end
