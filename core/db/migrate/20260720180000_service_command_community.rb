# frozen_string_literal: true

class ServiceCommandCommunity < ActiveRecord::Migration[8.1]
  def up
    add_reference :service_commands, :community, foreign_key: {on_delete: :cascade}

    # Every existing row predates the column and reached its community through the server, so seed from there.
    execute(<<~SQL)
      UPDATE service_commands
      SET community_id = servers.community_id
      FROM servers
      WHERE servers.id = service_commands.server_id
    SQL
  end

  def down
    remove_reference :service_commands, :community, foreign_key: true
  end
end
