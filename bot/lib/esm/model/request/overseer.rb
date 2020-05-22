# frozen_string_literal: true

module ESM
  class Request
    class Overseer
      def self.watch
        check_every = ESM.config.loops.request_overseer.check_every

        @thread = Thread.new do
          loop do
            ESM::Request.expired.each(&:expire)
            sleep(ESM.env.test? ? 0.5 : check_every)
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
