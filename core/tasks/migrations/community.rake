# frozen_string_literal: true

namespace :community do
  desc "Sets a server as default for a community if they only have one server"
  task assign_default_server: :environment do
    community_table = ESM::Community.arel_table
    server_table = ESM::Server.arel_table

    sql_statement = community_table.project(community_table[:id], server_table[:id])
      .join(server_table)
      .on(server_table[:community_id].eq(community_table[:id]))
      .where(
        server_table.grouping(
          server_table.project(server_table[:id].count)
            .where(server_table[:community_id].eq(community_table[:id]))
        )
        .eq(1)
      )
      .to_sql

    results = ESM::Server.connection.query(sql_statement)
    results.each do |(community_id, server_id)|
      default = ESM::CommunityDefault.where(community_id: community_id).first_or_initialize
      default.update!(server_id: server_id)
    end
  end

  desc "Backfills owner_user_id on communities by looking up each guild's Discord owner"
  task associate_to_owner_user: :discord_bot do
    ESM::Community.all.select(:id, :guild_id, :community_id).find_each do |community|
      owner_discord_id = community.discord_server.owner.id
      owner_user_id = ESM::User.by_discord_id(owner_discord_id).pick(:id)
      
      if owner_user_id.nil?
        puts "[ERROR] Failed to find ESM::User with discord_id=#{owner_discord_id} for ESM::Community<#{community.id}>."

        next
      end

      community.update!(owner_user_id:)
    end
  end
end
