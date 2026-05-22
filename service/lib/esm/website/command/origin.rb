# frozen_string_literal: true

module ESM
  module Website
    module Command
      ##
      # Website adapter for {ESM::Command::Origin}. Holds the user and community resolved
      # from a website-initiated RPC and forwards replies through the caller-supplied sink
      # so the lifecycle's reply path becomes the RPC's response body.
      #
      # {#current_channel} is always nil because the website has no channel context.
      #
      class Origin < ESM::Command::Origin
        attr_reader :current_user, :current_community, :current_channel

        def initialize(user:, reply_sink:, community: nil)
          @current_user = user
          @current_community = community
          @current_channel = nil
          @reply_sink = reply_sink
        end

        def reply(content)
          @reply_sink.call(serialize(content))
        end

        def log_context
          {
            author: "#{@current_user&.distinct} (steam #{@current_user&.steam_uid})",
            channel: "website"
          }
        end

        private

        def serialize(content)
          case content
          when ESM::Embed then content.to_h
          when String then {description: content}
          else content
          end
        end
      end
    end
  end
end
