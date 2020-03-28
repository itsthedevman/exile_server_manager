# frozen_string_literal: true

module ESM
  module Command
    module Server
      class Territories < ESM::Command::Base
        type :player

        limit_to :dm
        requires :registration

        define :enabled, modifiable: true, default: true
        define :whitelist_enabled, modifiable: true, default: false
        define :whitelisted_role_ids, modifiable: true, default: []
        define :allowed_in_text_channels, modifiable: true, default: false
        define :cooldown_time, modifiable: true, default: 2.seconds

        argument :server_id

        def discord
          deliver!(query: "list_territories", uid: current_user.esm_user.steam_uid)
        end

        def server
          check_for_no_territories!

          # Apparently past me I didn't default the response to an array if there was only one territory...
          @response = [@response] if @response.is_a?(OpenStruct)

          @response.each do |territory|
            reply(territory_embed(territory))
          end
        end

        module ErrorMessage
          def self.no_territories(user:, server_id:)
            I18n.t("commands.territories.no_territories", user: user, server_id: server_id)
          end
        end

        #########################
        # Command Methods
        #########################
        def check_for_no_territories!
          raise ESM::Exception::CheckFailure, error_message(:no_territories, user: current_user.mention, server_id: target_server.server_id) if @response.blank?
        end

        def territory_embed(territory)
          @territory = ESM::Arma::Territory.new(server: target_server, territory: territory)

          ESM::Embed.build do |e|
            e.title = "#{I18n.t(:territory)} \"#{@territory.name}\""
            e.thumbnail = @territory.flag_path
            e.color = @territory.status_color
            e.description = @territory.payment_reminder_message

            e.add_field(name: I18n.t(:territory_id), value: "```#{@territory.id}```", inline: true)
            e.add_field(name: I18n.t(:flag_status), value: "```#{@territory.flag_status}```", inline: true)
            e.add_field(name: I18n.t(:next_due_date), value: "```#{@territory.next_due_date.strftime(ESM::Time::Format::TIME)}```")
            e.add_field(name: I18n.t(:last_paid), value: "```#{@territory.last_paid_at.strftime(ESM::Time::Format::TIME)}```")
            e.add_field(name: I18n.t(:price_to_renew_protection), value: @territory.renew_price, inline: true)

            e.add_field(value: I18n.t("commands.territories.current_territory_stats"))
            e.add_field(name: I18n.t(:level), value: @territory.level, inline: true)
            e.add_field(name: I18n.t(:radius), value: "#{@territory.radius}m", inline: true)
            e.add_field(name: "#{I18n.t(:current)} / #{I18n.t(:max_objects)}", value: "#{@territory.object_count}/#{@territory.max_object_count}", inline: true)

            if @territory.upgradeable?
              e.add_field(value: I18n.t("commands.territories.next_territory_stats"))
              e.add_field(name: I18n.t(:level), value: @territory.upgrade_level, inline: true)
              e.add_field(name: I18n.t(:radius), value: "#{@territory.upgrade_radius}m", inline: true)
              e.add_field(name: I18n.t(:max_objects), value: @territory.upgrade_object_count, inline: true)
              e.add_field(name: I18n.t(:price), value: @territory.upgrade_price, inline: true)
            end

            e.add_field(value: I18n.t("commands.territories.territory_members"))
            e.add_field(name: I18n.t(:owner), value: @territory.owner)
            e.add_field(name: I18n.t(:moderators), value: @territory.moderators)
            e.add_field(name: I18n.t(:build_rights), value: @territory.builders)
          end
        end
      end
    end
  end
end
