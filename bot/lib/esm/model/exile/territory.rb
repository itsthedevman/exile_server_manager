# frozen_string_literal: true

module ESM
  module Exile
    class Territory
      # So I don't build a bad URL
      VALID_FLAGS = %w[
        flag_blue_co flag_country_at_co flag_country_au_co flag_country_be_co flag_country_by_co flag_country_cn_co
        flag_country_cz_co flag_country_de_co flag_country_dk_co flag_country_ee_co flag_country_fi_co flag_country_fr_co
        flag_country_ir_co flag_country_it_co flag_country_nl_co flag_country_pl2_co flag_country_pl_co flag_country_pt_co
        flag_country_ru_co flag_country_sct_co flag_country_se_co flag_cp_co flag_exile_city_co flag_green_co flag_mate_21dmd_co
        flag_mate_bis_co flag_mate_commandermalc_co flag_mate_hollow_co flag_mate_jankon_co flag_mate_legion_ca flag_mate_secretone_co
        flag_mate_spawny_co flag_mate_stitchmoonz_co flag_mate_vish_co flag_mate_zanders_streched_co flag_misc_alkohol_co flag_misc_battleye_co
        flag_misc_beardageddon_co flag_misc_brunswik_co flag_misc_bss_co flag_misc_dickbutt_co flag_misc_dorset_co flag_misc_dream_cat_co
        flag_misc_eraser1_co flag_misc_exile_co flag_misc_kickass_co flag_misc_kiwifern_co flag_misc_knuckles_co flag_misc_lazerkiwi_co
        flag_misc_lemonparty_co flag_misc_nuclear_co flag_misc_pedobear_co flag_misc_petoria_co flag_misc_pirate_co
        flag_misc_privateproperty_co flag_misc_rainbow_co flag_misc_rma_co flag_misc_skippy_co flag_misc_smashing_co flag_misc_snake_co
        flag_misc_svarog_co flag_misc_trololol_co flag_misc_utcity_co flag_misc_weeb_co flag_misc_willbeeaten_co flag_red_co
        flag_trouble2_co flag_uk_co flag_us_co flag_white_co
      ].freeze

      def initialize(server:, territory:)
        @server = server
        @territory = territory
        @server_settings = server.server_setting
        @current_level_territory = ESM::Territory.where(server_id: @server.id, territory_level: @territory.level).first
        @next_level_territory = ESM::Territory.where(server_id: @server.id, territory_level: @territory.level + 1).first
      end

      def id
        @territory.esm_custom_id.presence || @territory.id
      end

      def name
        @territory.territory_name
      end

      def owner
        "#{@territory.owner_name} (#{@territory.owner_uid})"
      end

      def level
        @territory.level
      end

      def object_count
        @territory.object_count
      end

      def radius
        # Radius comes in as a decimal
        @territory.radius.to_i
      end

      def flag_path
        @flag_path ||= convert_flag_path(@territory.flag_texture)
      end

      def stolen?
        @territory.flag_stolen
      end

      def flag_status
        stolen? ? "Stolen!" : "Secure"
      end

      def status_color
        if stolen? || days_left_until_payment_due <= 2
          ESM::Color::Toast::RED
        elsif days_left_until_payment_due <= 5
          ESM::Color::Toast::YELLOW
        else
          ESM::Color::Toast::GREEN
        end
      end

      def last_paid_at
        @last_paid_at ||= ESM::Time.parse(@territory.last_paid_at)
      end

      def next_due_date
        @next_due_date ||= last_paid_at + @server_settings.territory_lifetime.days
      end

      def max_object_count
        @current_level_territory.territory_object_count
      end

      def upgrade_level
        @next_level_territory.territory_level
      end

      def renew_price
        price = @territory.level * @territory.object_count * @server_settings.territory_price_per_object
        return "#{price} poptabs" if @server_settings.territory_payment_tax.zero?

        # If the server has tax, add it to the price
        price += (price * (@server_settings.territory_payment_tax.to_f / 100)).round

        "#{price} poptabs (#{@server_settings.territory_payment_tax}% tax added)"
      end

      def upgradeable?
        !@next_level_territory.nil?
      end

      def upgrade_price
        price = @next_level_territory.territory_purchase_price
        return "#{price} poptabs" if @server_settings.territory_upgrade_tax.zero?

        # If the server has tax, add it to the price
        price += (price * (@server_settings.territory_upgrade_tax.to_f / 100)).round

        "#{price} poptabs (#{@server_settings.territory_upgrade_tax}% tax added)"
      end

      def upgrade_radius
        @next_level_territory.territory_radius
      end

      def upgrade_object_count
        @next_level_territory.territory_object_count
      end

      def moderators
        @territory.moderators.map { |name, uid| "#{name} (#{uid})" }
      end

      def builders
        @territory.build_rights.map { |name, uid| "#{name} (#{uid})" }
      end

      def days_left_until_payment_due
        @days_left_until_payment_due ||= (next_due_date.to_date - ::Time.zone.today).to_i
      end

      def payment_reminder_message
        time_left_message = "You have `#{ESM::Time.distance_of_time_in_words(next_due_date, precise: false)}` until your next payment is due."

        case days_left_until_payment_due
        when 0..2
          # 0 to 2 days left
          ":alarm_clock: **You should make a base payment ASAP to avoid losing your base!**\n#{time_left_message}"
        when 3..5
          # 3 to 5 days left
          ":warning: **You should consider making a base payment soon.**\n#{time_left_message}"
        else
          # Don't show anything
          ""
        end
      end

      def to_embed
        ESM::Embed.build do |e|
          e.title = "#{I18n.t(:territory)} \"#{name}\""
          e.thumbnail = flag_path
          e.color = status_color
          e.description = payment_reminder_message

          e.add_field(name: I18n.t(:territory_id), value: "```#{id}```", inline: true)
          e.add_field(name: I18n.t(:flag_status), value: "```#{flag_status}```", inline: true)
          e.add_field(name: I18n.t(:next_due_date), value: "```#{next_due_date.strftime(ESM::Time::Format::TIME)}```")
          e.add_field(name: I18n.t(:last_paid), value: "```#{last_paid_at.strftime(ESM::Time::Format::TIME)}```")
          e.add_field(name: I18n.t(:price_to_renew_protection), value: renew_price, inline: true)

          e.add_field(value: I18n.t("commands.territories.current_territory_stats"))
          e.add_field(name: I18n.t(:level), value: level, inline: true)
          e.add_field(name: I18n.t(:radius), value: "#{radius}m", inline: true)
          e.add_field(name: "#{I18n.t(:current)} / #{I18n.t(:max_objects)}", value: "#{object_count}/#{max_object_count}", inline: true)

          if upgradeable?
            e.add_field(value: I18n.t("commands.territories.next_territory_stats"))
            e.add_field(name: I18n.t(:level), value: upgrade_level, inline: true)
            e.add_field(name: I18n.t(:radius), value: "#{upgrade_radius}m", inline: true)
            e.add_field(name: I18n.t(:max_objects), value: upgrade_object_count, inline: true)
            e.add_field(name: I18n.t(:price), value: upgrade_price, inline: true)
          end

          e.add_field(value: I18n.t("commands.territories.territory_members"))
          e.add_field(name: I18n.t(:owner), value: owner)
          e.add_field(name: I18n.t(:moderators), value: moderators)
          e.add_field(name: I18n.t(:build_rights), value: builders)
        end
      end

      private

      def convert_flag_path(arma_path)
        flag_base_path = "https://exile-server-manager.s3.amazonaws.com/flags"
        default_flag = "#{flag_base_path}/flag_white_co.jpg"
        return default_flag if arma_path.blank?

        flag_name = arma_path.match(ESM::Regex::FLAG_NAME)
        return default_flag if flag_name.blank?

        flag_path = "#{flag_base_path}/#{flag_name[1]}.jpg"

        # If we have a version of this flag, return the path, otherwise, just return the default flag
        VALID_FLAGS.include?(flag_name[1]) ? flag_path : default_flag
      end
    end
  end
end
