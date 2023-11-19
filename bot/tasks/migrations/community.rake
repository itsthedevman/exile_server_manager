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
end
