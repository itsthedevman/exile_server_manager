# frozen_string_literal: true

module ESM
  class ExileTerritory < ArmaRecord
    class ArmaError < ESM::Exception::Error
    end

    FLAG_TEXTURES = %w[
      exile_assets\texture\flag\flag_mate_bis_co.paa exile_assets\texture\flag\flag_mate_vish_co.paa exile_assets\texture\flag\flag_mate_hollow_co.paa
      exile_assets\texture\flag\flag_mate_legion_ca.paa exile_assets\texture\flag\flag_mate_21dmd_co.paa exile_assets\texture\flag\flag_mate_spawny_co.paa
      exile_assets\texture\flag\flag_mate_secretone_co.paa exile_assets\texture\flag\flag_mate_stitchmoonz_co.paa
      exile_assets\texture\flag\flag_mate_commandermalc_co.paa \A3\Data_F\Flags\flag_blue_co.paa \A3\Data_F\Flags\flag_green_co.paa
      \A3\Data_F\Flags\flag_red_co.paa \A3\Data_F\Flags\flag_white_co.paa \A3\Data_F\Flags\flag_uk_co.paa exile_assets\texture\flag\flag_country_de_co.paa
      exile_assets\texture\flag\flag_country_at_co.paa exile_assets\texture\flag\flag_country_sct_co.paa exile_assets\texture\flag\flag_country_ee_co.paa
      exile_assets\texture\flag\flag_country_cz_co.paa exile_assets\texture\flag\flag_country_nl_co.paa exile_assets\texture\flag\flag_country_hr_co.paa
      exile_assets\texture\flag\flag_country_cn_co.paa exile_assets\texture\flag\flag_country_ru_co.paa exile_assets\texture\flag\flag_country_ir_co.paa
      exile_assets\texture\flag\flag_country_by_co.paa exile_assets\texture\flag\flag_country_fi_co.paa exile_assets\texture\flag\flag_country_fr_co.paa
      exile_assets\texture\flag\flag_country_au_co.paa exile_assets\texture\flag\flag_country_be_co.paa exile_assets\texture\flag\flag_country_se_co.paa
      exile_assets\texture\flag\flag_country_pl_co.paa exile_assets\texture\flag\flag_country_pl2_co.paa exile_assets\texture\flag\flag_country_pt_co.paa
      exile_assets\texture\flag\flag_mate_zanders_streched_co.paa exile_assets\texture\flag\flag_misc_brunswik_co.paa
      exile_assets\texture\flag\flag_misc_dorset_co.paa exile_assets\texture\flag\flag_misc_svarog_co.paa exile_assets\texture\flag\flag_misc_exile_co.paa
      exile_assets\texture\flag\flag_misc_utcity_co.paa exile_assets\texture\flag\flag_misc_dickbutt_co.paa exile_assets\texture\flag\flag_misc_rainbow_co.paa
      exile_assets\texture\flag\flag_misc_battleye_co.paa exile_assets\texture\flag\flag_misc_bss_co.paa exile_assets\texture\flag\flag_misc_skippy_co.paa
      exile_assets\texture\flag\flag_misc_kiwifern_co.paa exile_assets\texture\flag\flag_misc_trololol_co.paa exile_assets\texture\flag\flag_misc_dream_cat_co.paa
      exile_assets\texture\flag\flag_misc_pirate_co.paa exile_assets\texture\flag\flag_misc_pedobear_co.paa exile_assets\texture\flag\flag_misc_petoria_co.paa
      exile_assets\texture\flag\flag_misc_smashing_co.paa exile_assets\texture\flag\flag_misc_lemonparty_co.paa exile_assets\texture\flag\flag_misc_rma_co.paa
      exile_assets\texture\flag\flag_cp_co.paa exile_assets\texture\flag\flag_trouble2_co.paa exile_assets\texture\flag\flag_exile_city_co.paa
      exile_assets\texture\flag\flag_misc_eraser1_co.paa exile_assets\texture\flag\flag_misc_willbeeaten_co.paa
      exile_assets\texture\flag\flag_misc_privateproperty_co.paa exile_assets\texture\flag\flag_misc_nuclear_co.paa
      exile_assets\texture\flag\flag_misc_lazerkiwi_co.paa exile_assets\texture\flag\flag_misc_beardageddon_co.paa exile_assets\texture\flag\flag_country_dk_co.paa
      exile_assets\texture\flag\flag_country_it_co.paa exile_assets\texture\flag\flag_misc_alkohol_co.paa exile_assets\texture\flag\flag_misc_kickass_co.paa
      exile_assets\texture\flag\flag_misc_knuckles_co.paa exile_assets\texture\flag\flag_misc_snake_co.paa exile_assets\texture\flag\flag_misc_weeb_co.paa
    ].freeze

    self.table_name = "territory"

    attribute :id, :integer
    attribute :server_id, :integer # Not a database field in mysql
    attribute :esm_custom_id, :string
    attribute :owner_uid, :string
    attribute :name, :string
    attribute :position_x, :float
    attribute :position_y, :float
    attribute :position_z, :float
    attribute :radius, :float
    attribute :level, :integer
    attribute :flag_texture, :string
    attribute :flag_stolen, :boolean, default: false
    attribute :flag_stolen_by_uid, :string
    attribute :flag_stolen_at, :datetime
    attribute :created_at, :datetime, default: -> { Time.current }
    attribute :last_paid_at, :datetime, default: -> { Time.current }
    attribute :xm8_protectionmoney_notified, :boolean, default: false
    attribute :build_rights, :json
    attribute :moderators, :json
    attribute :esm_payment_counter, :integer, default: 0
    attribute :deleted_at, :datetime

    # Not database backed
    attribute :number_of_constructions, :integer, default: 0

    alias_attribute :territory_name, :name

    has_many :containers,
      class_name: "ESM::ExileContainer",
      foreign_key: "territory_id",
      dependent: :destroy

    has_many :constructions,
      class_name: "ESM::ExileConstruction",
      foreign_key: "territory_id",
      dependent: :destroy

    after_save :update_arma

    scope :active, -> { where(deleted_at: nil) }
    scope :not_stolen, -> { where(flag_stolen: false) }
    scope :owned_by, ->(user) { where(owner_uid: user.steam_uid) }
    scope :not_owned_by, ->(user) { where.not(owner_uid: user.steam_uid) }
    scope :built_by, ->(user) { where("build_rights LIKE ?", "%#{user.steam_uid}%") }
    scope :moderated_by, ->(user) { where("moderators LIKE ?", "%#{user.steam_uid}%") }
    scope :not_moderated_by, ->(user) { where.not("moderators LIKE ?", "%#{user.steam_uid}%") }

    scope :with_no_membership_for, ->(user) do
      where.not(owner_uid: user.steam_uid)
        .and(where.not("build_rights LIKE ?", "%#{user.steam_uid}%"))
        .and(where.not("moderators LIKE ?", "%#{user.steam_uid}%"))
    end

    def self.sampled_for(server)
      territory = all.sample
      territory.tap { |t| t.server_id = server.id }
    end

    def object_count
      constructions.size
    end

    def owner_name
      name_lookup[owner_uid]
    end

    def add_moderators!(*steam_uids)
      self.moderators |= steam_uids
      self.build_rights |= steam_uids

      save! if changed?
      self
    end

    alias_method :add_moderator!, :add_moderators!

    def add_builders!(*steam_uids)
      self.build_rights |= steam_uids

      save! if changed?
      self
    end

    alias_method :add_builder!, :add_builders!

    def revoke_membership(steam_uid)
      self.owner_uid = ESM::Test.steam_uid if owner_uid == steam_uid
      moderators.delete(steam_uid)
      build_rights.delete(steam_uid)
      save! if changed?
      self
    end

    def change_owner(steam_uid)
      old_owner_uid = owner_uid

      moderators.delete(old_owner_uid)
      build_rights.delete(old_owner_uid)

      self.owner_uid = steam_uid
      self.moderators |= [steam_uid]
      self.build_rights |= [steam_uid]

      save! if changed?
      self
    end

    def server
      ESM::Server.find(server_id)
    end

    def encoded_id
      @encoded_id ||= begin
        hashids = Hashids.new(server.server_key, 5, "abcdefghijklmnopqrstuvwxyz")
        hashids.encode(id)
      end
    end

    def create_flag
      sqf = <<~SQF
        private _territory = #{id} call ESMs_system_territory_get;
        if !(isNull _territory) exitWith { true };

        #{id} call ExileServer_system_territory_database_load;

        sleep 0.1;
        private _territory = #{id} call ESMs_system_territory_get;
        if (isNull _territory) exitWith { false };

        #{set_variables(MAPPING.keys)}

        !(isNull _territory)
      SQF

      success = server.execute_sqf!(sqf)
      raise ArmaError, "Failed to create flag for territory id:#{id}" unless success
    end

    def delete_flag
      # The sleep is required because Arma deletes a vehicle on the next frame
      sqf = <<~SQF
        private _territory = #{id} call ESMs_system_territory_get;
        if (isNull _territory) exitWith { true };

        deleteVehicle _territory;

        sleep 0.1;
        private _territory = #{id} call ESMs_system_territory_get;
        isNull(_territory)
      SQF

      success = server.execute_sqf!(sqf)
      raise ArmaError, "Failed to delete flag for territory id:#{id}" unless success
    end

    def name_lookup
      name_lookup = ExileAccount.all.pluck(:uid, :name).to_h
      name_lookup.default = "Name not found"
      name_lookup
    end

    def moderators_as_hash
      moderators.map { |uid| {uid:, name: name_lookup[uid]} }
        .sort_by { |hash| hash[:name].downcase }
    end

    def builders_as_hash
      build_rights.map { |uid| {uid:, name: name_lookup[uid]} }
        .sort_by { |hash| hash[:name].downcase }
    end

    def to_h
      attrs = %i[
        id esm_custom_id
        owner_uid radius level
        flag_texture flag_stolen last_paid_at
        build_rights moderators
      ]

      attributes.symbolize_keys.slice(*attrs).tap do |hash|
        hash[:owner_name] = owner_name
        hash[:territory_name] = territory_name
        hash[:object_count] = object_count
        hash[:moderators] = moderators_as_hash
        hash[:build_rights] = builders_as_hash
        hash[:last_paid_at] = hash[:last_paid_at].strftime(ESM::Time::Format::SQL_TIME)
      end
    end

    private

    MAPPING = {
      owner_uid: "ExileOwnerUID",
      moderators: "ExileTerritoryModerators",
      build_rights: "ExileTerritoryBuildRights",
      flag_stolen: "ExileFlagStolen",
      radius: "ExileTerritorySize",
      level: "ExileTerritoryLevel",
      number_of_constructions: "ExileTerritoryNumberOfConstructions",
      esm_payment_counter: "ESM_PaymentCounter",
      last_paid_at: "ExileTerritoryLastPayed"
    }.stringify_keys.freeze

    def set_variables(items)
      items.join_map(" ") do |attribute|
        arma_variable = MAPPING[attribute]
        if arma_variable.nil?
          warn!(
            "Territory attribute #{attribute.quoted} was updated but does not have a MAPPING entry"
          )
          next
        end

        value =
          if attribute == "flag_stolen"
            flag_stolen ? 1 : 0
          elsif attribute == "last_paid_at"
            last_paid_at.strftime(ESM::Time::Format::SQL_TIME)
          else
            public_send(attribute)
          end

        "_territory setVariable [#{arma_variable.to_json}, #{value.to_json}];"
      end
    end

    # _territory setVariable ["ExileTerritoryName", _name, true];
    # _territory setVariable ["ExileDatabaseID", _id];
    # _territory setVariable ["ExileOwnerUID", _owner, true];
    # _territory setVariable ["ExileTerritorySize", _radius, true];
    # _territory setVariable ["ExileTerritoryLevel", _level, true];
    # _territory setVariable ["ExileTerritoryLastPayed", _lastPayed];
    # _territory call ExileServer_system_territory_maintenance_recalculateDueDate;
    # _territory setVariable ["ExileTerritoryNumberOfConstructions", _data select 15, true];
    # _territory setVariable ["ExileRadiusShown", false, true];
    # _territory setVariable ["ExileFlagStolen",_flagStolen,true];
    # _territory setVariable ["ExileFlagTexture",_flagTexture];
    def update_arma
      return if previously_new_record?

      changed_items = previous_changes.slice(*MAPPING.keys)
      return if changed_items.blank?

      sqf = <<~STRING
        private _territory = #{id} call ESMs_system_territory_get;
        #{set_variables(changed_items.keys)}
      STRING

      server.execute_sqf!(sqf)
    end
  end
end
