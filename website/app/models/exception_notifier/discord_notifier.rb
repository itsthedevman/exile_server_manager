# frozen_string_literal: true

module ExceptionNotifier
  class DiscordNotifier
    def initialize(options)
      # do something with the options...
    end

    def call(exception, options = {})
      backtrace = Rails.backtrace_cleaner.clean(exception.backtrace[0..10]).join("\n\t")
      HTTParty.post(
        "https://discord.com/api/webhooks/1067235053307973633/IaH7FWosk3nYj0YOd3-T9-4Pu1wwLkS1pLfMsbNocI3XpMN8bZjgvmmlEbyH3imu4Q3H",
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
