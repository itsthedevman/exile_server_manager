# frozen_string_literal: true

module ESM
  module Command
    class Cache
      attr_accessor :name, :type, :category, :description, :arguments, :examples, :usage, :defines
      def initialize(**opts)
        @name = opts[:name]
        @type = opts[:type]
        @category = opts[:category]
        @description = opts[:description]
        @arguments = opts[:arguments]
        @examples = opts[:examples]
        @usage = opts[:usage]
        @defines = opts[:defines]
      end

      def build!
        ESM::Command.build(@name, @category)
      end
    end
  end
end
