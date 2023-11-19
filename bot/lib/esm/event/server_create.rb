# frozen_string_literal: true

module ESM
  module Event
    class ServerCreate
      def initialize(server)
        @server = server
        @owner = server.owner

        @community = ESM::Community.from_discord(@server)
        @user = ESM::User.from_discord(@owner)
      end

      def run!
        # Send the welcome message
        send_welcome
      end

      private

      def send_welcome
        embed =
          ESM::Embed.build do |e|
            e.title = "**Hello #{@owner.name}, thank you for inviting me to your community!**"

            change_mode_usage = ESM::Command.get(:mode).usage(
              with_args: true,
              arguments: {for: @community.community_id}
            )

            e.description = [
              "If this is your first time inviting me, please read my [Getting Started](https://www.esmbot.com/wiki) guide. It goes over how to use my commands and any extra setup that may need done. You can also use the `/help` command if you need detailed information on how to use a command.\nIf you encounter a bug, please join my developer's [Discord Server](https://www.esmbot.com/join) and let him know in the support channel :smile:",
              "",
              "**If you host Exile Servers, please read the following message**",
              "||In order for players to run commands on your servers, I've assigned you `#{@community.community_id}` as your community ID. This ID will be used in commands to let players distinguish which community they want run the command on.",
              "Don't worry about memorizing it quite yet. You can always change it later via the [Admin Dashboard](https://www.esmbot.com/dashboard).",
              "One more thing, before you can link your servers with me, I'll need you to disable [Player Mode](https://www.esmbot.com/wiki/player_mode). Please reply back to this message with `#{change_mode_usage}`||"
            ]
          end

        ESM.bot.deliver(embed, to: @owner)
      end
    end
  end
end
