# frozen_string_literal: true

module ESM
  class ExilePlayer < ArmaRecord
    self.table_name = "player"

    attribute :id, :integer
    attribute :name, :string
    attribute :account_uid, :string
    attribute :money, :integer, default: 0
    attribute :damage, :float, default: 0
    attribute :hunger, :float, default: 100
    attribute :thirst, :float, default: 100
    attribute :alcohol, :float, default: 0
    attribute :temperature, :float, default: 37
    attribute :wetness, :float, default: 0
    attribute :oxygen_remaining, :float, default: 0
    attribute :bleeding_remaining, :float, default: 1
    attribute :hitpoints, :json, default: [["face_hub", 0], ["neck", 0], ["head", 0], ["pelvis", 0], ["spine1", 0], ["spine2", 0], ["spine3", 0], ["body", 0], ["arms", 0], ["hands", 0], ["legs", 0], ["body", 0]]
    attribute :direction, :float, default: 0
    attribute :position_x, :float, default: 0
    attribute :position_y, :float, default: 0
    attribute :position_z, :float, default: 0
    attribute :spawned_at, :datetime, default: -> { Time.current }
    attribute :assigned_items, :json, default: []
    attribute :backpack, :string, default: ""
    attribute :backpack_items, :json, default: []
    attribute :backpack_magazines, :json, default: []
    attribute :backpack_weapons, :json, default: []
    attribute :current_weapon, :string, default: ""
    attribute :goggles, :string, default: ""
    attribute :handgun_items, :json, default: []
    attribute :handgun_weapon, :string, default: ""
    attribute :headgear, :string, default: ""
    attribute :binocular, :string, default: ""
    attribute :loaded_magazines, :json, default: []
    attribute :primary_weapon, :string, default: ""
    attribute :primary_weapon_items, :json, default: ["", "", "", ""]
    attribute :secondary_weapon, :string, default: ""
    attribute :secondary_weapon_items, :json, default: ["", "", "", ""]
    attribute :uniform, :string, default: ""
    attribute :uniform_items, :json, default: []
    attribute :uniform_magazines, :json, default: []
    attribute :uniform_weapons, :json, default: []
    attribute :vest, :string, default: ""
    attribute :vest_items, :json, default: []
    attribute :vest_magazines, :json, default: []
    attribute :vest_weapons, :json, default: []
    attribute :last_updated_at, :datetime, default: -> { Time.current }

    def self.from(user)
      model =
        where(account_uid: user.steam_uid).first_or_initialize.tap do |player|
          ExileAccount.from(user) # This'll create the account if it doesn't exist

          player.name = user.discord_username
        end

      model.save!
      model
    end

    alias_method :kill!, :destroy!
  end
end
