# frozen_string_literal: true

module ExceptionNotifier
  class DiscordNotifier
    def initialize(options)
      # do something with the options...
    end

    def call(exception, options = {})
      backtrace = Rails.backtrace_cleaner.clean(exception.backtrace[0..10]).join("\n\t")
      HTTParty.post(
        Settings.discord.logging_webhook_url,
        body: {
          content: <<~STRING
            `#{Time.current}`
            **`#{exception.class}`**
            ```
            #{exception}
              #{backtrace}
            ```
            ```
            #{JSON.pretty_generate(options[:env]["exception_notifier.exception_data"])}
            ```
          STRING
        }
      )
    end
  end
end
