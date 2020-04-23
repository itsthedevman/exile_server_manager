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
            outro = "I highly suggest taking a look at our [wiki](https://www.esmbot.com/wiki) for information on getting started. It also contains my [commands](https://www.esmbot.com/wiki/commands), and information about [Player Mode](https://www.esmbot.com/wiki/player_mode)."

            e.description =
              if server_owner
                "Awesome! I've disabled player mode for you. This means you can now manage your community and servers in the server portal on our website. But first, #{outro}"
              else
                "Excellent! I've left player mode enabled so you and your friends can use my player commands in your Discord server. But first, #{outro}"
              end

            e.add_field(
              name: "Admin Commands and Player Commands",
              value: "Every player command can be used in this channel freely, however, their usage in Discord servers may vary. Server admins can disable player commands from being ran in their Discord, but I will let you know when you can't use that command in that channel.\nAdmin Commands can **only** be used in a Discord server and they can only be used by roles specified by the Server admins."
            )

            e.add_field(
              name: "Need help?",
              value: "At any time, you can use the `#{ESM.config.prefix}help` command for quick information. If you don't find your question, or if you have an issue, please join our discord and let us know :smile:"
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
