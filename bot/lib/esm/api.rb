# frozen_string_literal: true

module ESM
  class API < Sinatra::Base
    def self.run!
      Thread.new { super; quit! }
    end

    # Sinatra hooks the Ctrl-C event.
    # This method is now in charge of killing everything. yaay /s
    def self.quit!
      super

      # Stop the bot
      ESM.bot.stop
    end

    # Sinatra server configuration below
    set(:port, ENV["API_PORT"])

    before do
      halt(401) if request.env["HTTP_ESM_AUTH"] != ENV["API_AUTH_KEY"]
    end

    put("/requests/:uuid/accept") do
      ESM.logger.debug("#{self.class}##{__method__}") { "API /requests/#{params[:uuid]}/accept" }

      request = ESM::Request.where(uuid: params[:uuid]).first
      return halt(404) if request.nil?

      # Respond to the request
      request.respond(true)
    end

    put("/requests/:uuid/decline") do
      ESM.logger.debug("#{self.class}##{__method__}") { "API /requests/#{params[:uuid]}/decline" }

      request = ESM::Request.where(uuid: params[:uuid]).first
      return halt(404) if request.nil?

      # Respond to the request
      request.respond(false)
    end
  end
end
