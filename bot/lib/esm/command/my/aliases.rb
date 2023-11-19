# frozen_string_literal: true

module ESM
  module Command
    module My
      class Aliases < ApplicationCommand
        #################################
        #
        # Configuration
        #

        change_attribute :enabled, modifiable: false
        change_attribute :allowlist_enabled, modifiable: false

        command_type :player

        #################################

        def on_execute
          embed =
            ESM::Embed.build do |e|
              e.title = "My aliases"

              description = ""
              aliases = current_user.id_aliases.by_type

              if (id_aliases = aliases[:community]) && id_aliases.size > 0
                description += "**Community Aliases**\n#{build_table("Community", id_aliases)}"
              end

              if (id_aliases = aliases[:server]) && id_aliases.size > 0
                description += "**Server Aliases**\n#{build_table("Server", id_aliases)}"
              end

              description = "You do not have any aliases, yet. " if description.blank?
              description += "*Aliases can be managed from the [player dashboard](https://esmbot.com/users/#{current_user.discord_id}/edit#id_aliases)*"

              e.description = description
            end

          reply(embed)
        end

        private

        def build_table(type, id_aliases)
          id_aliases.format(join_with: "\n") do |id_alias|
            if id_alias.server_id
              server = id_alias.server
              id = server.server_id
              name = server.server_name
            else
              community = id_alias.community
              id = community.community_id
              name = community.community_name
            end

            <<~STRING
              **[#{id}] #{name}**
              ```#{id_alias.value}```
            STRING
          end
        end
      end
    end
  end
end
