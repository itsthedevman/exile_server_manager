# frozen_string_literal: true

module ESM
  class Server
    class Metadata
      KEYS = %i[
        vg_enabled
        vg_max_sizes
        initialized
      ].freeze

      def initialize(uuid)
        @uuid = uuid

        KEYS.each do |key|
          class_eval <<-METHODS, __FILE__, __LINE__ + 1
            def #{key}=(val)
              @#{key} = val.to_s
              ESM.redis.hset(redis_hash_key, "#{key}", @#{key})
              ESM.redis.expire(redis_hash_key, 172_800) # 2 days
            end

            def #{key}
              ESM.redis.hget(redis_hash_key, "#{key}")
            end
          METHODS
        end
      end

      def redis_hash_key
        "metadata_#{@uuid}"
      end

      def clear!
        KEYS.each do |key|
          ESM.redis.del(redis_hash_key, key)
        end
      end
    end
  end
end
