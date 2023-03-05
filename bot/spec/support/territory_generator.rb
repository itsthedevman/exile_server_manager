# frozen_string_literal: true

class TerritoryGenerator
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

  TERRITORY_LEVELS = [
    {price: 5_000, radius: 15, object_count: 30},
    {price: 10_000, radius: 30, object_count: 60},
    {price: 15_000, radius: 45, object_count: 90},
    {price: 20_000, radius: 60, object_count: 120},
    {price: 25_000, radius: 75, object_count: 150},
    {price: 30_000, radius: 90, object_count: 180},
    {price: 35_000, radius: 105, object_count: 210},
    {price: 40_000, radius: 120, object_count: 240},
    {price: 45_000, radius: 135, object_count: 270},
    {price: 50_000, radius: 150, object_count: 300}
  ].freeze

  TIME_FORMAT = "%FT%H:%M:%S"

  # {
  #   id,
  #   owner_uid,
  #   owner_name,
  #   territory_name
  #   radius
  #   level
  #   flag_texture
  #   flag_stolen
  #   last_paid_at
  #   build_rights
  #   moderators
  #   object_count
  #   esm_custom_id
  # }
  def self.generate(moderator_count: 3, extra_builders: 0, level: nil, stolen: nil)
    level = level.nil? ? Faker::Number.between(from: 1, to: TERRITORY_LEVELS.size - 1) : level
    raise StandardError, "Level of territory does not exist in TERRITORY_LEVELS" if level > TERRITORY_LEVELS.size

    level_info = TERRITORY_LEVELS[level - 1]
    stolen =
      if stolen.nil?
        rand > 0.7
      else
        stolen
      end

    # Each tier shows up in each array.
    owner = generate_player_name_and_uid.first
    moderators = [owner] + generate_player_name_and_uid(count: moderator_count)
    builders = moderators + generate_player_name_and_uid(count: extra_builders)

    {
      id: Faker::Crypto.md5[0, 5],
      owner_uid: owner.second,
      owner_name: owner.first,

      # Sometimes the test data contains apostrophes
      territory_name: Faker::Name.name.to_json,
      radius: level_info[:radius],
      level: level,
      flag_texture: FLAG_TEXTURES.sample(1).first,
      flag_stolen: stolen,
      last_paid_at: Faker::Time.between(from: 7.days.ago, to: Date.today).utc.strftime(TIME_FORMAT),
      build_rights: builders,
      moderators: moderators,
      object_count: Faker::Number.between(from: 0, to: level_info[:object_count]),
      esm_custom_id: rand > 0.6 ? Faker::Name.first_name.downcase : nil
    }
  end

  # Generates a player's name and uid as an array
  #
  # @private
  # @params count [Integer] The number of players to generate
  # @return [Array] An array of arrays that contain name and uid
  # @example Returned array
  #   [
  #     ["Name", "UID"],
  #     ["Name", "UID"]
  #   ]
  def self.generate_player_name_and_uid(count: 1)
    return [] if count <= 0

    count.times.map do
      [Faker::Name.name, Faker::Number.number(digits: 17).to_s]
    end
  end
end
