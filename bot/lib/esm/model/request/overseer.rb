# frozen_string_literal: true

module ESM
  class Request
    class Overseer
      def self.watch
        check_every = ESM.config.loops.request_overseer.check_every

        @thread = Thread.new do
          loop do
            ESM::Request.expired.destroy_all
            sleep(check_every)
          end
        end
      end

      def self.die
        return if @thread.nil?

        Thread.kill(@thread)
      end
    end
  end
end
