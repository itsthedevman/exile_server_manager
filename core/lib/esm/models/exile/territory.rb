# frozen_string_literal: true

module ESM
  module Exile
    class Territory
      # Days-left window within which #payment_due_soon? flags a territory.
      PAYMENT_DUE_SOON_DAYS = 3

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

      # An addressable member of a territory: enough to render the person and to
      # target them for a promote / demote / remove action on the website. role is
      # one of :owner, :moderator, :builder.
      Member = Data.define(:name, :steam_uid, :role)

      def initialize(server:, territory:)
        @server = server
        @server_settings = server.server_setting
        @territory = normalize_territory(territory)
      end

      def id
        @territory[:esm_custom_id].presence || @territory[:id]
      end

      def name
        @territory[:name]
      end

      def level
        @territory[:level]
      end

      def object_count
        @territory[:object_count]
      end

      def radius
        # Radius comes in as a decimal
        @territory[:radius].to_i
      end

      def flag_path
        @flag_path ||= convert_flag_path(@territory[:flag_texture])
      end

      def stolen?
        @territory[:flag_stolen]
      end

      def flag_status
        stolen? ? "Stolen!" : "Secure"
      end

      def status_color
        days = days_left_until_payment_due

        return ESM::Color::Toast::RED if stolen?
        return ESM::Color::Toast::GREEN if days.nil?

        if days <= 2
          ESM::Color::Toast::RED
        elsif days <= 5
          ESM::Color::Toast::YELLOW
        else
          ESM::Color::Toast::GREEN
        end
      end

      def last_paid_at
        return if @territory[:last_paid_at].blank?

        @last_paid_at ||= ESM::Time.parse(@territory[:last_paid_at])
      end

      def next_due_date
        return if last_paid_at.nil?

        @next_due_date ||= last_paid_at + @server_settings.territory_lifetime.days
      end

      def max_object_count
        current_level_territory.territory_object_count
      end

      def upgrade_level
        next_level_territory.territory_level
      end

      def current_level_territory
        @current_level_territory ||= @server.territories.find_by(territory_level: @territory[:level])
      end

      def next_level_territory
        @next_level_territory ||= @server.territories.find_by(territory_level: @territory[:level] + 1)
      end

      def renew_cost
        cost = @territory[:level] *
          @territory[:object_count] *
          @server_settings.territory_price_per_object

        return cost if @server_settings.territory_payment_tax.zero?

        # Add the server's payment tax on top of the base cost
        cost + (cost * (@server_settings.territory_payment_tax.to_f / 100)).round
      end

      def renew_price
        return "#{renew_cost.to_delimitated_s} poptabs" if @server_settings.territory_payment_tax.zero?

        "#{renew_cost.to_delimitated_s} poptabs (#{@server_settings.territory_payment_tax}% tax added)"
      end

      def upgradeable?
        !next_level_territory.nil?
      end

      def upgrade_price
        price = next_level_territory.territory_purchase_price
        return "#{price.to_delimitated_s} poptabs" if @server_settings.territory_upgrade_tax.zero?

        # If the server has tax, add it to the price
        price += (price * (@server_settings.territory_upgrade_tax.to_f / 100)).round

        "#{price.to_delimitated_s} poptabs (#{@server_settings.territory_upgrade_tax}% tax added)"
      end

      def upgrade_radius
        next_level_territory.territory_radius
      end

      def upgrade_object_count
        next_level_territory.territory_object_count
      end

      # The territory's members as addressable Member objects
      # v2 servers only; a v1 territory renders its flatter shape directly in #to_embed and never reaches these
      def owner
        Member.new(name: @territory[:owner_name], steam_uid: @territory[:owner_uid], role: :owner)
      end

      def moderators
        @moderators ||= build_members(@territory[:moderators], role: :moderator) { |account| !account[:owner] }
      end

      def builders
        @builders ||= build_members(@territory[:build_rights], role: :builder) do |account|
          !account[:owner] && !account[:moderator]
        end
      end

      def days_left_until_payment_due
        return if next_due_date.nil?

        @days_left_until_payment_due ||= (next_due_date.to_date - ::Time.zone.today).to_i
      end

      # Whether a protection payment is close enough to surface a call to action.
      # Drives the website's pay panels and its "payment due" grouping.
      def payment_due_soon?
        days = days_left_until_payment_due
        return false if days.nil?

        days <= PAYMENT_DUE_SOON_DAYS
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

          e.add_field(
            name: I18n.t(:next_due_date),
            value: "```#{next_due_date.strftime(ESM::Time::Format::TIME)}```"
          )

          e.add_field(
            name: I18n.t(:last_paid),
            value: "```#{last_paid_at.strftime(ESM::Time::Format::TIME)}```"
          )

          e.add_field(name: I18n.t(:price_to_renew_protection), value: renew_price, inline: true)

          e.add_field(value: I18n.t("commands.territories.current_territory_stats"))
          e.add_field(name: I18n.t(:level), value: level, inline: true)
          e.add_field(name: I18n.t(:radius), value: "#{radius}m", inline: true)

          e.add_field(
            name: "#{I18n.t(:current)} / #{I18n.t(:max_objects)}",
            value: "#{object_count}/#{max_object_count}",
            inline: true
          )

          if upgradeable?
            e.add_field(value: I18n.t("commands.territories.next_territory_stats"))
            e.add_field(name: I18n.t(:level), value: upgrade_level, inline: true)
            e.add_field(name: I18n.t(:radius), value: "#{upgrade_radius}m", inline: true)
            e.add_field(name: I18n.t(:max_objects), value: upgrade_object_count, inline: true)
            e.add_field(name: I18n.t(:price), value: upgrade_price, inline: true)
          end

          e.add_field(value: I18n.t("commands.territories.territory_members"))

          if @server.v2?
            e.add_field(name: ":crown: #{I18n.t(:owner)}", value: embed_member(owner))

            if moderators.present?
              e.add_field(name: ":shield: #{I18n.t(:moderators)}", value: embed_member_list(moderators))
            end

            if builders.present?
              e.add_field(name: ":construction_site: #{I18n.t(:build_rights)}", value: embed_member_list(builders))
            end
          else
            # V1 stores members as bare [name, uid] pairs, rendered only here.
            e.add_field(name: ":crown: #{I18n.t(:owner)}", value: "#{@territory[:owner_name]} (#{@territory[:owner_uid]})")

            v1_moderators = @territory[:moderators].map { |name, uid| "#{name} (#{uid})" }
            e.add_field(name: ":shield: #{I18n.t(:moderators)}", value: v1_moderators) if v1_moderators.present?

            v1_builders = @territory[:build_rights].map { |name, uid| "#{name} (#{uid})" }
            e.add_field(name: ":construction_site: #{I18n.t(:build_rights)}", value: v1_builders) if v1_builders.present?
          end
        end
      end

      private

      # Discord embed rendering of a v2 member: "Name (steam_uid)".
      def embed_member(member)
        "#{member.name} (#{member.steam_uid})"
      end

      def embed_member_list(members)
        members.join_map("\n") { |member| embed_member(member) }
      end

      # Builds the Member list for a role from the raw v2 account hashes, keeping
      # only the accounts the predicate accepts.
      def build_members(accounts, role:, &includes_account)
        return [] if accounts.blank?

        accounts.filter_map do |account|
          next unless includes_account.call(account)

          Member.new(name: account[:name], steam_uid: account[:uid], role:)
        end
      end

      def normalize_territory(territory)
        territory = territory.to_h unless territory.is_a?(Hash)
        territory = transform_territory(territory) if @server.v2?

        territory[:name] = territory[:territory_name] if territory.key?(:territory_name)
        territory[:esm_custom_id] ||= nil

        territory
      end

      def transform_territory(territory)
        moderator_uids = territory[:moderators]&.map { |a| a[:uid] } || []
        builder_uids = territory[:build_rights]&.map { |a| a[:uid] } || []

        label_accounts = lambda do |account|
          account[:owner] = account[:uid] == territory[:owner_uid]
          account[:moderator] = moderator_uids.include?(account[:uid])
          account[:builder] = builder_uids.include?(account[:uid])
        end

        sort_accounts = ->(account) { account[:name].downcase }

        territory[:moderators]&.each(&label_accounts)&.sort_by!(&sort_accounts)
        territory[:build_rights]&.each(&label_accounts)&.sort_by!(&sort_accounts)

        territory
      end

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
