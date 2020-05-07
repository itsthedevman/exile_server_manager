# frozen_string_literal: true

module ESM
  module Event
    class ServerCreate
      def initialize(event)
        @event = event
        @server = event.server
        @owner = event.server.owner

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
              "I'm excited to get start, but first, I have a question to ask you.",
              "It appears I was invited to and joined your Discord server, _#{@server.name}_. Does your community host Exile Servers?"
            ]

            e.add_field(value: "_Just reply back `yes` or `no` when you're ready_")
            e.footer = "If I don't reply back to these messages, just reply back with `#{ESM.config.prefix}setup`"
          end

        response = ESM.bot.deliver_and_await!(embed, to: @owner, expected: %w[yes no])

        # This is a server community, turn off player mode
        if (server_owner = (response.downcase == "yes"))
          @community.update(player_mode_enabled: false)
        end

        embed =
          ESM::Embed.build do |e|
            e.title = "Welcome to the ESM Community!"

            # For the description
            e.description = "I went ahead and #{server_owner ? "disabled" : "enabled"} Player Mode for you. #{server_owner ? "Disabling" : "Enabling"} [Player Mode](https://www.esmbot.com/wiki/player_mode) means members of your Discord #{server_owner ? "cannot" : "can"} run commands, in your Discord, for other communities and their servers. This also affects Admin commands and your community's ability to link servers. For more information, I highly suggest checking out my [wiki](https://www.esmbot.com/wiki)."

            e.add_field(
              name: "Need help?",
              value: "At any time, you can use the `#{ESM.config.prefix}help` command for quick information. Having an issue? Please join our [discord](https://www.esmbot.com/join) and let us know :smile:"
            )

            e.add_field(
              name: "One final thing, just in case",
              value: "If you meant to say _#{server_owner ? "no" : "yes"}_ to that question, you can #{server_owner ? "enable" : "disable"} player mode by sending me `#{ESM.config.prefix}mode #{server_owner ? "player" : "server"}`. I won't tell :wink:"
            )
          end

        ESM.bot.deliver(embed, to: @owner)
      end
    end
  end
end
