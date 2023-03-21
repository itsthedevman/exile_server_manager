# frozen_string_literal: true

module ESM
  module Event
    class MemberJoin
      def initialize(event)
        @user = event.user
        @server = event.server
        @community = ESM::Community.where(guild_id: @server.id).first_or_create!
      end

      def run!
        return if !@community.welcome_message_enabled?

        thread = Thread.new do
          if @community.guild_id == ESM::Community::ESM::ID
            send_esm_welcome_message
          else
            send_community_welcome_message
          end
        end

        thread.join if ESM.env.test?
      end

      private

      def send_esm_welcome_message
        embed =
          ESM::Embed.build do |e|
            e.set_author(name: ESM.bot.profile.username, url: "https://www.esmbot.com", icon_url: ESM.bot.profile.avatar_url)
            e.title = "Welcome to my Discord!"

            e.description = "We're happy you're here! Please feel free to make yourself at home and be sure to check out our rules in the #welcome-to-esm channel."

            e.add_field(
              name: "Looking to chat or have a non-support related question?",
              value: "Feel free to ask in #general-no-support"
            )

            e.add_field(
              name: "Having an issue that needs fixin'?",
              value: "Let us know in #general-support"
            )
          end

        ESM.bot.deliver(embed, to: @user)
      end

      def send_community_welcome_message
        servers = @community.servers.public_visibility.map { |server| "#{server.server_name} [#{server.server_ip}:#{server.server_port}]\nServer ID: #{server.server_id}" }.join("\n\n")

        description = "First off, let me introduce myself. My name is Exile Server Manager, or ESM for short. My purpose is to give you the ability to interact with aspects of Exile that would normally require you to be in game. This includes getting information about your player, managing your territory (paying, upgrading, add/remove members, etc), XM8 notifications, random fun commands, and so much more!"
        description += "\n\n**A message from this community:**\n#{@community.welcome_message}" if @community.welcome_message.present?

        embed =
          ESM::Embed.build do |e|
            e.set_author(name: ESM.bot.profile.username, url: "https://www.esmbot.com", icon_url: ESM.bot.profile.avatar_url)
            e.title = "Welcome to #{@community.community_name}, #{@user.username}!"
            e.description = description

            e.add_field(name: "This community's ID", value: "```#{@community.community_id}```")
            e.add_field(name: "This community's servers", value: "```#{servers}```") if servers.present?
            e.add_field(name: "New to ESM?", value: "Please check out the Getting Started guide on my website: https://www.esmbot.com/wiki")
            e.add_field(name: "Want to invite ESM to your own Discord?", value: "https://www.esmbot.com/invite")
          end

        ESM.bot.deliver(embed, to: @user)
      end
    end
  end
end
