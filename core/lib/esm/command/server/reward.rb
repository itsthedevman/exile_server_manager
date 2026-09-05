# frozen_string_literal: true

module ESM
  module Command
    module Server
      class Reward < ApplicationCommand
        MINIMUM_SERVER_VERSION = "2.1.0"

        # Nothing retries on its own, so every attempt is the player running the command again. Reaching this many
        # means they have hit the same wall five times, which is no longer a transient one they can wait out.
        MAX_DELIVERY_ATTEMPTS = 5

        # What a delivery form may decide about a vehicle. Everything else on a claim's entry belongs to the admin who
        # configured the package.
        DELIVERY_CHOICE_KEYS = %i[spawn_location territory_id pin_code].freeze

        #################################
        #
        # Arguments (required first, then order matters)
        #

        # See Argument::TEMPLATES[:server_id]
        argument :server_id, display_name: :on

        argument :reward_id, :string, required: false

        #
        # Website arguments (order does not matter)
        #

        # The choices only the player can make and only a form can ask for, one entry per vehicle on the claim, in the
        # claim's own order. Never stored: a pin sitting in the claims table for as long as a claim goes undelivered
        # is a door code with no owner, and a territory picked weeks ago may not be theirs any more.
        argument :vehicles, :string, origins: [:website], required: false

        #
        # Configuration
        #

        command_type :player

        # We need to manually handle cooldowns
        skip_action :cooldown

        #################################

        def on_execute
          check_for_pending_request!

          claim = load_and_check_claim!

          add_request(to: current_user, description: request_description(claim))

          # Ignore PM channels to avoid double messages
          return if current_channel.pm?

          # Remind them to check their PMs
          embed = ESM::Embed.build(
            :success,
            description: I18n.t("commands.request.check_pm", user: current_user.mention)
          )

          reply(embed)
        end

        def on_request_accepted
          response = deliver_reward!

          reply(embed_from_message!(response.embed))
        end

        # The page reads the claim back out of the database itself, so the reply carries only what the row cannot say
        # afterwards: how the attempt went, and any failure that was dropped rather than kept for a retry.
        def on_website_execute
          response = deliver_reward!

          reply(state: response.state, failures: failure_details(response))
        end

        module V1
          def on_response
            # Array<Array<item, quantity>>
            receipt = @response.receipt.to_h

            embed = ESM::Embed.build(
              :success,
              description: I18n.t(
                "commands.reward_v1.receipt",
                user: current_user.mention,
                items: receipt.join_map { |item, quantity| "- #{quantity}x #{item}\n" }
              )
            )

            reply(embed)
          end

          def on_request_accepted
            deliver!(command_name: "reward", function_name: "rewardPlayer", target_uid: current_user.steam_uid)
          end
        end

        private

        def server_reward
          @server_reward ||=
            if arguments.reward_id.present? && target_server.version?(MINIMUM_SERVER_VERSION)
              target_server.server_rewards.find_by(reward_id: arguments.reward_id)
            else
              target_server.server_rewards.default.first
            end
        end

        def reward_claim
          current_user.server_reward_claims.find_by(server_id: target_server.id)
        end

        def check_for_reward!(reward)
          return if reward

          raise_error!(:incorrect_reward_id, user: current_user, reward_id: arguments.reward_id || "default")
        end

        def check_for_reward_items!(reward)
          return if reward.rewards?

          raise_error!(:no_reward_items, user: current_user)
        end

        def request_description(claim)
          base_key =
            if claim.is_a?(ESM::ServerRewardClaim)
              "claim_base"
            else
              "reward_base"
            end

          contents = claim.contents

          base = [
            I18n.t(
              "commands.reward.request_descriptions.#{base_key}",
              user: current_user.mention,
              server_id: target_server.server_id,
              # Only reward_base names the package. A claim has no reward_id and its copy does not ask for one.
              reward_id: claim.try(:reward_id)
            )
          ]

          if (value = contents.player_poptabs).positive?
            base << I18n.t("commands.reward.request_descriptions.player_poptabs", value:)
          end

          if (value = contents.locker_poptabs).positive?
            base << I18n.t("commands.reward.request_descriptions.locker_poptabs", value:)
          end

          if (value = contents.respect).positive?
            base << I18n.t("commands.reward.request_descriptions.respect", value:)
          end

          if (value = contents.items).present?
            value = value.join_map("\n") { |item| "#{item.quantity}x - #{item.display_name}" }
            base << I18n.t("commands.reward.request_descriptions.items", value:)
          end

          if (value = contents.vehicles).present?
            value = value.join_map("\n") do |vehicle|
              location =
                case vehicle.spawn_location
                when "nearby"
                  "spawned nearby"
                when "virtual_garage"
                  "added to your virtual garage"
                when "player_decides"
                  "spawn location to be decided"
                end

              "#{vehicle.display_name} - #{location}"
            end

            base << I18n.t("commands.reward.request_descriptions.vehicles", value:)
          end

          base.join("\n")
        end

        def load_and_check_claim!
          claim = reward_claim

          if claim.nil?
            claim = server_reward
            check_for_reward!(claim)

            # Ensure they didn't claim their reward via the website
            check_for_cooldown!(scope_key: claim.reward_id)
            check_for_reward_items!(claim)
          else
            check_for_exhausted_claim!(claim)
          end

          claim
        end

        def check_for_exhausted_claim!(claim)
          return unless claim.failed?

          raise_error!(:claim_exhausted, user: current_user, attempts: MAX_DELIVERY_ATTEMPTS)
        end

        #
        # Hands the player whatever they are owed and records what came back. Both surfaces run this; they differ only
        # in how they report it, since Discord answers with an embed the extension built and the website answers with
        # something its own page can render.
        #
        # @return [ESM::Message::Data] the extension's response data
        #
        def deliver_reward!
          reward = load_and_check_claim!
          is_package = reward.is_a?(ESM::ServerReward)

          # Resolved before the package becomes a claim. A form that no longer lines up should not leave the player
          # holding a mailbox they have to work through in place of a package they could simply redeem again.
          vehicles = delivery_vehicles(is_package ? reward.reward_vehicles : reward.vehicles)

          # A claim row is where a partial delivery lives, so the package becomes one before it is attempted
          claim = is_package ? create_claim(reward) : reward

          # The extension resolves display names off its own config, so it only needs the raw stored shapes
          data = {
            items: claim.items,
            locker: claim.locker_poptabs,
            money: claim.player_poptabs,
            respect: claim.respect
          }

          # Only this version and greater can handle vehicles
          data[:vehicles] = vehicles if target_server.version?(MINIMUM_SERVER_VERSION)

          claim.update!(state: :in_flight)

          response = call_sqf_function!("ESMs_command_reward", **data).data
          settle_claim!(claim, response)

          response
        end

        #
        # The claim's vehicles with the player's delivery choices folded in. Discord never sends any, so the claim's
        # own entries are what goes out; a `player_decides` vehicle then fails and waits for the website, which is the
        # only surface that can ask.
        #
        # @param stored_vehicles [Array<Hash>] the vehicle entries the package or claim holds
        #
        # @return [Array<Hash>]
        #
        def delivery_vehicles(stored_vehicles)
          choices = arguments.vehicles
          return stored_vehicles if choices.blank?

          # The form is built from what it was rendered against, so a different count means that moved out from under
          # it and the choices no longer line up with the vehicles they were made for
          if choices.size != stored_vehicles.size
            raise_error!(:stale_delivery, user: current_user)
          end

          stored_vehicles.map.with_index do |vehicle, index|
            vehicle.merge(delivery_choice_for(vehicle, choices[index]))
          end
        end

        #
        # One vehicle's choices, narrowed to what a player is allowed to decide. Sliced rather than merged wholesale:
        # everything else on the entry is the admin's configuration, and a class name arriving from a form would let a
        # player pick their own vehicle.
        #
        # @param vehicle [Hash] the claim's stored entry
        # @param choice [Hash, nil] what the form sent for it
        #
        # @return [Hash]
        #
        def delivery_choice_for(vehicle, choice)
          choice = (choice || {}).slice(*DELIVERY_CHOICE_KEYS).compact_blank

          pin_code = choice[:pin_code]

          # Exile only ever compares a pin against a four character string, and spawnReward silently generates one
          # when what it is handed is not that. A player would never learn the code to their own vehicle.
          raise_error!(:invalid_pin_code, user: current_user) if pin_code && !pin_code.match?(/\A\d{4}\z/)

          # The admin picked a spawn location unless they explicitly handed that choice to the player
          choice.delete(:spawn_location) unless vehicle[:spawn_location] == "player_decides"

          choice
        end

        def create_claim(reward)
          ESM::ServerRewardClaim.create!(
            server_id: target_server.id,
            user_id: current_user.id,
            reward_id: reward.reward_id,
            player_poptabs: reward.player_poptabs,
            locker_poptabs: reward.locker_poptabs,
            respect: reward.respect,
            items: reward.reward_items,
            vehicles: reward.reward_vehicles,
            state: :waiting
          )
        end

        # TODO: Detect a reward vehicle being destroyed in the first seconds after it spawns and count it as
        # undelivered. Needs in-game testing to find a window that catches a bad spawn without holding the response.

        #
        # Records what the extension could not deliver. Poptabs and respect are all or nothing with the attempt, so only
        # items and vehicles can come back. Anything that did land is gone from the claim for good.
        #
        # Keys off what came back rather than the reported state: an item with a classname the server does not have is
        # reported as a failure but cannot be retried, so it is dropped and the claim can still settle.
        #
        # @param claim [ESM::ServerRewardClaim] the claim that was just attempted
        # @param result [ESM::Message::Data] the extension's response data
        #
        # @return [void]
        #
        def settle_claim!(claim, result)
          undelivered_items = result.undelivered_items.presence || {}
          undelivered_vehicles = result.undelivered_vehicles.presence || []

          if undelivered_items.blank? && undelivered_vehicles.blank?
            start_package_cooldown(claim)

            return claim.destroy!
          end

          attempt_count = claim.attempt_count + 1

          # No cooldown on a partial. The player still has an unfinished claim, and the cooldown gates issuing a new
          # package, not finishing this one.
          claim.update!(
            player_poptabs: 0,
            locker_poptabs: 0,
            respect: 0,
            items: undelivered_items,
            vehicles: undelivered_vehicles,
            state: (attempt_count >= MAX_DELIVERY_ATTEMPTS) ? :failed : :waiting,
            state_details: {failures: failure_details(result)},
            attempt_count:,
            last_attempt_at: Time.current
          )
        end

        #
        # Puts the package this claim came from on cooldown, now that the player has actually received it.
        #
        # The claim carries the package's id rather than a copy of its cooldown. Contents are copied because they are
        # a promise to the player; a cooldown is a rule the community sets, so shortening one is meant to apply to
        # everyone rather than draining through the outstanding claims first.
        #
        # @param claim [ESM::ServerRewardClaim] the claim that just finished
        #
        # @return [void]
        #
        def start_package_cooldown(claim)
          # An admin built this claim by hand, so no package was redeemed and nothing goes on cooldown. Passing the
          # nil through would not be a no-op: nil is the command's own unscoped cooldown, which gates every package.
          return if claim.reward_id.blank?

          # Deliberately not #server_reward, which falls back to the default package. The claim names its own.
          package = target_server.server_rewards.find_by(reward_id: claim.reward_id)

          # A package sets its own cooldown; one that doesn't falls back to whatever the community configured for the
          # command itself
          duration = package&.cooldown_time || cooldown_time

          create_or_update_cooldown(scope_key: claim.reward_id, duration:)
        end

        # The bucket is what makes these actionable later: an admin granting vehicles onto a claim clears the vehicle
        # reasons and leaves the item ones alone, which needs to know which is which.
        def failure_details(result)
          (result.failures || []).map { |bucket, name, reason| {bucket:, name:, reason:} }
        end
      end
    end
  end
end
