# frozen_string_literal: true

module ESM
  module Command
    class Base
      class Timers
        def initialize(command_name)
          @command_name = command_name

          @timers = {
            on_execute: ESM::Time::Timer.new,
            on_response: ESM::Time::Timer.new,
            from_discord: ESM::Time::Timer.new,
            from_server: ESM::Time::Timer.new,
            from_request: ESM::Time::Timer.new
          }
        end

        def reset_all!
          @timers.values.each(&:reset!)
        end

        def stop_all!
          @timers.values.each(&:stop!)
        end

        def to_h
          @timers.transform_values(&:to_h)
        end

        def time!(timer_name, &block)
          timer = @timers[timer_name.to_sym]
          raise "Invalid timer name: #{timer_name}. Expected one of #{@timers.keys.to_sentence(last_word_connector: ", or ")}" if timer.nil?

          timer.start!
          yield
          timer.stop!

          info!(timer: timer_name, command: @command_name, time_elapsed: "#{timer.time_elapsed * 1000} ms")
          nil
        end

        def method_missing(method_name, *_arguments, &_block)
          @timers[method_name.to_sym]
        end

        def respond_to_missing?(method_name, _include_private = false)
          @timer.key?(method_name.to_sym)
        end
      end
    end
  end
end
