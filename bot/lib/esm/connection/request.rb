# frozen_string_literal: true

module ESM
  module Connection
    class Request < Data.define(:id, :type, :content)
      # These numbers MUST match the associated ServerRequestType enum value in esm_arma/src/esm/src/bot.rs
      TYPES = {
        0 => :noop,
        1 => :error,
        2 => :identification,
        3 => :handshake,
        4 => :initialize,
        5 => :message
      }.freeze

      def self.from_client(data)
        new(id: data[:i], type: TYPES[data[:t]], content: data[:c].pack("C*"))
      end

      delegate :to_json, to: :to_h

      def initialize(type:, id: nil, content: nil)
        id ||= SecureRandom.uuid
        id = id.delete("-")

        raise ArgumentError, "ID must be 32 bytes" if id.size != 32 # The size of a UUID without the dashes
        raise ArgumentError, "Invalid type #{type}" unless TYPES.value?(type.to_sym)

        super(id: id, type: type, content: content)
      end

      def to_h
        {
          i: id,
          t: TYPES.key(type),
          c: case content
             when NilClass
               []
             when Array
               content
             when Symbol
               content.to_s.bytes
             when ->(c) { c.respond_to?(:bytes) }
               content.bytes
             else
               raise ArgumentError, "Content must be nil, Symbol, Array, or must respond to #bytes"
             end
        }
      end
    end
  end
end
