# frozen_string_literal: true

module ESM
  module Command
    class Base
      class Timers < Hash
        include ActionView::Helpers::NumberHelper

        def initialize(command_name)
          @command_name = command_name
          super
        end

        def reset_all!
          values.each(&:reset!)
        end

        def stop_all!
          values.each(&:stop!)
        end

        def to_h
          transform_values(&:to_h)
        end

        def time!(timer_name, &block)
          timer = create_timer(timer_name)

          timer.start!
          yield
          timer.stop!

          info!(
            timer: timer_name,
            command: @command_name,
            time_elapsed: "#{timer.time_elapsed * 1000} ms"
          )

          nil
        end

        def humanized_total
          time_elapsed = values.sum(&:time_elapsed)

          # Milliseconds
          if (milliseconds = (time_elapsed * 1_000).round) && milliseconds <= 1_000
            return "#{number_with_delimiter(milliseconds)} #{"millisecond".pluralize(milliseconds)}"
          end

          # Microseconds
          if (microseconds = (time_elapsed * 1_000_000).round) && microseconds <= 1_000_000
            return "#{number_with_delimiter(microseconds)} #{"microsecond".pluralize(microseconds)}"
          end

          # Seconds and above
          start_time = values.map(&:started_at).min
          ESM::Time.distance_of_time_in_words(start_time + time_elapsed.seconds, from_time: start_time)
        end

        private

        def create_timer(name)
          name = name.to_sym

          timer = Timer.new

          self[name] = timer
          self.class.define_method(name) { self[name] }

          timer
        end
      end
    end
  end
end
