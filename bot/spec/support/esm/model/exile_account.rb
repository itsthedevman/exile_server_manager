# frozen_string_literal: true

module ESM
  class ExileAccount < ArmaRecord
    self.table_name = "account"

    attribute :uid, :string
    attribute :clan_id, :integer, default: nil
    attribute :name, :string
    attribute :score, :integer, default: 0
    attribute :kills, :integer, default: 0
    attribute :deaths, :integer, default: 0
    attribute :locker, :integer, default: 0
    attribute :first_connect_at, :datetime, default: -> { Time.current }
    attribute :last_connect_at, :datetime, default: -> { Time.current }
    attribute :last_disconnect_at, :datetime
    attribute :total_connections, :integer, default: 1

    def self.from(user)
      where(uid: user.steam_uid).first_or_create do |account|
        account.name = user.discord_username
      end
    end
  end
end
