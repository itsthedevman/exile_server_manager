# frozen_string_literal: true

module ESM
  module Command
    class Base
      module Metadata
        # V1: name is defined in the migrations file, but will need to be added here once v1 has been deprecated
        attr_reader :category, :type, :aliases, :limit_to,
          :requires, :response, :cooldown_time,
          :defines, :permissions, :checks, :skip_flags

        attr_writer :current_community

        attr_accessor :executed_at, :event, :arguments

        def usage
          @usage ||= "#{distinct} #{@arguments.map(&:to_s).join(" ")}"
        end

        # Don't memoize this, prefix can change based on when its called
        def distinct
          "#{prefix}#{name}"
        end

        def offset
          distinct.size
        end

        def example
          I18n.t("commands.#{@name}.example", prefix: prefix, default: "")
        end

        def description
          I18n.t("commands.#{@name}.description", prefix: prefix, default: "")
        end

        def prefix
          return ESM.config.prefix if current_community&.command_prefix.nil?

          current_community.command_prefix
        end
      end
    end
  end
end
