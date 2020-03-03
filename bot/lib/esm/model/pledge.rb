# frozen_string_literal: true

module ESM
  class Pledge < ApplicationRecord
    attribute :uuid, :uuid
    attribute :community_id, :integer, default: nil
    attribute :redeeming_user_id, :integer, default: nil
    attribute :patreon_email, :encrypted
    attribute :pledge_type, :integer, default: 0
    attribute :redeemed_at, :datetime
    attribute :created_at, :datetime
    attribute :updated_at, :datetime
    attribute :deleted_at, :datetime

    belongs_to :community
    belongs_to :user

    TYPES = {
      "0": {
        name: "No Pledge",
        patreon_id: "-1"
      },

      "1": {
        name: "The Exiled",
        patreon_id: "2566679"
      },

      "-1": {
        name: "Mafia Boss",
        patreon_id: "2566709"
      }
    }

    def tier
      tier = TYPES[self.type.to_sym]
      Struct.new(:id, :name).new(self.type, tier[:name])
    end

    def destroy
      if !self.community_id.blank?
        # Update the community
        self.community.update(premium_state: "0")

        # Update all their servers
        self.community.servers.each do |server|
          server.update(is_premium: false)
          ESMBot.update_server(server)
        end
      end

      self.deleted_at = DateTime.now
      self.save
    end
  end
end
