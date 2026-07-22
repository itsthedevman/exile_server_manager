# frozen_string_literal: true

module ESM
  module Website
    module Command
      ##
      # Origin for a command the website is waiting on. Mirrors {ESM::Website::Command::AsyncOrigin}, except there is
      # no row to settle: the web request that asked for the value is still open, so the reply is captured here and
      # handed straight back to the caller.
      #
      class SyncOrigin < ESM::Command::Origin
        attr_reader :current_user, :current_community, :results

        def initialize(event)
          @current_user = event.user
          @current_community = event.community
          @source = :website
          @results = nil
        end

        # The website doesn't execute from within a channel
        def current_channel = nil

        def reply(content)
          @results = content
        end

        def reply_error(error)
          raise error
        end
      end
    end
  end
end
