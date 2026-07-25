# frozen_string_literal: true

module ESM
  class << self
    def bot
      Bot
    end

    def env
      Rails.env
    end

    def config
      {print_to_stdout: true}.to_struct
    end

    def backtrace_cleaner
      Rails.backtrace_cleaner
    end

    # ESM.cache is the cross-process store the bot and this app share: same Redis, same namespace, so data one side
    # computes (a community's territory-admin users, for one) is readable by the other without a round-trip. Rails.cache
    # stays Solid Cache - this is only ESM's shared keyspace. Namespace and connection mirror the bot's ESM.cache in
    # service/lib/esm.rb; the two must move together or the keyspaces drift apart.
    #
    # Test keeps Rails.cache (a null store): the website's specs stub the bot's API rather than reading its cache, so a
    # live cross-process store would only add flakiness, not coverage.
    def cache
      return Rails.cache if Rails.env.test?

      @cache ||= ActiveSupport::Cache::RedisCacheStore.new(
        namespace: "esm_bot",
        host: ENV.fetch("REDIS_HOST", "localhost"),
        reconnect_attempts: 10,
        pool: {size: 5, timeout: 5}
      )
    end
  end
end
