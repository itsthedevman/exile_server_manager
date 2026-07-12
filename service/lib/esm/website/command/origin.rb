# frozen_string_literal: true

module ESM
  module Website
    module Command
      class Origin < ESM::Command::Origin
        def initialize(server_command)
          @server_command = server_command
        end

        def current_user
          @server_command.user
        end

        def reply(content)
          raise ArgumentError, "You can only reply to this origin once" if @server_command.settled?

          @server_command.update!(status: :completed, result: content)
        end

        #
        # Settles the row as failed with the error rendered for the web: a keyed CheckFailure is projected with
        # the player's username (never a Discord mention) and prefers a "_web" copy variant when one exists;
        # anything else falls back to its literal content. Markup is stripped since the page renders plain text.
        #
        def reply_error(error)
          raise ArgumentError, "You can only reply to this origin once" if @server_command.settled?

          body =
            if error.is_a?(ESM::Exception::CheckFailure) && error.key
              error.render(suffix: "_web", &:username)
            else
              project_player(error.to_content)
            end

          @server_command.update!(status: :failed, error_message: strip_markup(body))
        end

        def log_context
          {
            server_command: @server_command.attributes
          }
        end

        # The website doesn't execute from within a community
        def current_community = nil

        # The website doesn't execute from within a channel
        def current_channel = nil

        private

        # Extension and other literal errors are authored for Discord with the player's mention or Steam UID
        # baked into the text. Swap whichever token appears for their name so the website reads naturally.
        def project_player(text)
          name = current_user.username.presence || "you"
          tokens = [current_user.mention, current_user.steam_uid].compact_blank

          tokens.reduce(text) { |message, token| message.gsub(token, name) }
        end

        # Discord copy carries **bold**/`code` markup; the website renders plain text, so drop it.
        def strip_markup(text)
          text.to_s.gsub(/\*\*(.*?)\*\*/, '\1').delete("`").strip
        end
      end
    end
  end
end
