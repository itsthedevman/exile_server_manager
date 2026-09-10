# frozen_string_literal: true

module Communities
  module Servers
    class RewardsController < AuthenticatedController
      before_action :check_for_community_access!
      before_action :require_packaged_rewards!

      def new
        render locals: {package: current_server.server_rewards.new}
      end

      def create
        package = current_server.server_rewards.new(package_params)

        return render :new, locals: {package:}, status: :unprocessable_content unless package.save

        render turbo_stream: saved_streams("#{package_label(package)} has been created")
      end

      def edit
        package = find_package
        not_found! if package.nil?

        render locals: {package:}
      end

      def update
        package = find_package
        not_found! if package.nil?

        unless package.update(package_params)
          return render :edit, locals: {package:}, status: :unprocessable_content
        end

        render turbo_stream: saved_streams("#{package_label(package)} has been updated")
      end

      ##
      # Flipped from what is stored rather than from what the page sent, so a switch drawn against a list that has
      # moved on cannot write the state it was drawn with. The list comes back either way, showing what is true.
      #
      # @return [void]
      #
      def toggle_enabled
        package = find_package
        not_found! if package.nil?

        package.update!(enabled: !package.enabled?)

        message =
          if package.enabled?
            "Players can claim #{package_label(package)}"
          else
            "#{package_label(package)} is turned off"
          end

        render turbo_stream: [list_stream, create_success_toast(message)]
      end

      def destroy
        package = find_package
        not_found! if package.nil?

        # The player dashboard offers this one outright and the command falls back to it, so a server without one is a
        # reward command that answers nobody. Turning it off is what the enabled switch is for.
        if package.default?
          return render turbo_stream: create_error_toast("The default package cannot be deleted")
        end

        label = package_label(package)
        package.destroy!

        render turbo_stream: saved_streams("#{label} has been deleted")
      end

      private

      def current_server
        @current_server ||= begin
          # Nesting prefixes a resource's own param with its parent's name, the same as it does for the community
          public_id = params[:server_server_id] || params[:server_id]

          current_community&.servers&.includes(:server_rewards)&.find_by(public_id:)
        end
      end

      helper_method :current_server

      ##
      # Packaged rewards are a v2 UI feature rather than a v2 extension one, so an owner can build their packages
      # before they update the server that will hand them out. A v1 server is still told what to give from the data it
      # was sent when it connected, which only ever describes the one default package.
      #
      # @return [void]
      #
      def require_packaged_rewards!
        not_found! if current_server.nil? || !current_server.ui_v2?
      end

      def find_package
        current_server.server_rewards.find_by(reward_id: params[:reward_id])
      end

      def package_label(package)
        helpers.reward_package_name(package)
      end

      ##
      # The whole list rather than the one row that changed. A package can arrive, leave, or be renamed into a
      # different place in the order, and all three are the list re-rendering.
      #
      # @param message [String] what the toast says
      #
      # @return [Array]
      #
      def saved_streams(message)
        [list_stream, hide_modal("#reward_package_modal"), create_success_toast(message)]
      end

      def list_stream
        turbo_stream.replace(
          "reward_packages_list",
          partial: "communities/servers/rewards/list",
          locals: {current_server: current_server.reload}
        )
      end

      def package_params
        permitted_params = params.require(:reward_package).permit(
          :name, :reward_id, :enabled, :custom_cooldown,
          :player_poptabs, :locker_poptabs, :respect,
          :cooldown_quantity, :cooldown_type,
          reward_items: [:classname, :quantity],
          reward_vehicles: [:class_name, :spawn_location]
        )

        # The code is what a player types and what addresses this package in the URL. Changing the default's would
        # leave the command falling back to a package that no longer answers to the name it falls back on.
        permitted_params.delete(:reward_id) if find_package&.default?

        sanitize_reward_items(permitted_params)
        sanitize_reward_vehicles(permitted_params)
        sanitize_cooldown(permitted_params)

        permitted_params
      end

      def sanitize_reward_items(permitted_params)
        rows = permitted_params[:reward_items]

        permitted_params[:reward_items] =
          if rows.present?
            rows
              .group_by_key(:classname)
              .transform_values { |items| items.sum { |item| item[:quantity].to_i } }
              .reject { |classname, quantity| classname.blank? || quantity < 1 }
          else
            {}
          end

        permitted_params[:reward_items].permit!
      end

      ##
      # Vehicles are the one part of a package the extension has to be new enough to act on, so an older server's
      # editor never renders the fields. Its existing entries are left where they are rather than emptied: the server
      # it belongs to is one update away from being able to hand them out.
      #
      # @param permitted_params [ActionController::Parameters]
      #
      # @return [void]
      #
      def sanitize_reward_vehicles(permitted_params)
        rows = permitted_params.delete(:reward_vehicles)
        return unless helpers.reward_packages_vehicles_supported?(current_server)

        permitted_params[:reward_vehicles] = Array(rows).filter_map do |vehicle|
          class_name = vehicle[:class_name].to_s.strip
          next if class_name.blank?

          {
            class_name:,
            spawn_location: vehicle[:spawn_location].presence_in(
              ESM::ServerReward::VEHICLE_SPAWN_LOCATIONS
            ) || "nearby"
          }
        end
      end

      # Both columns are cleared together rather than left half filled, since a package without its own cooldown is
      # one that falls back to the command's, and that is what the switch is asking.
      def sanitize_cooldown(permitted_params)
        return if permitted_params.delete(:custom_cooldown) == "1"

        permitted_params[:cooldown_quantity] = nil
        permitted_params[:cooldown_type] = nil
      end
    end
  end
end
