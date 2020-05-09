# frozen_string_literal: true

module ESM
  module Event
    class ServerCreate
      def initialize(server)
        @server = server
        @owner = server.owner

        @community = find_or_initialize_community
        @user = find_or_initialize_user
      end

      def run!
        thread = Thread.new do
          # Update their guild name
          update_community_name

          # Send the welcome message
          send_welcome
        end

        thread.join if ESM.env.test?
      end

      private

      def find_or_initialize_community
        # Attempt to find the community by it's guild id
        community = ESM::Community.find_by_guild_id(@server.id)
        community.nil? ? ESM::Community.create!(guild_id: @server.id) : community
      end

      def find_or_initialize_user
        user = ESM::User.find_by_discord_id(@owner.id)
        @new_user = user.nil?
        @new_user ? ESM::User.create!(discord_id: @owner.id, discord_username: @owner.name, discord_discriminator: @owner.discriminator) : user
      end

      def update_community_name
        @community.update(community_name: @server.name)
      end

      def send_welcome
        embed =
          ESM::Embed.build do |e|
            e.title = "**Hello #{@owner.name}, thank you for inviting me to your community!**"
            e.description = [
              "If this is your first time inviting me, please read my [Getting Started](https://www.esmbot.com/wiki) guide. It goes over how to use my commands and any extra setup that may need done. You can also use the `#{ESM.config.prefix}help` command if you need detailed information on how to use a command.\nIf you encounter a bug, please join my developer's [Discord Server](https://www.esmbot.com/join) and let him know in the support channel :smile:",
              "",
              "**If you host Exile Servers, please read the following message**",
              "||In order for players to run commands on your servers, I've assigned you `#{@community.community_id}` as your community ID. This ID will be used in commands to let players distinguish which community they want run the command on.",
              "Don't worry about memorizing it quite yet. You can always change it later via the [Server Dashboard](https://www.esmbot.com/login).",
              "One more thing, before you can link your servers with me, I'll need you to disable [Player Mode](https://www.esmbot.com/wiki/player_mode). Please reply back to this message with `#{ESM.config.prefix}mode server`||"
            ]
          end

        ESM.bot.deliver(embed, to: @owner)
      end
    end
  end
end
