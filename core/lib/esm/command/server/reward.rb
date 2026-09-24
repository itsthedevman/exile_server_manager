# frozen_string_literal: true

module ESM
  module Command
    module Server
      class Reward < ApplicationCommand
        include RewardContents

        MINIMUM_SERVER_VERSION = ESM::Server::MINIMUM_REWARD_VEHICLES_VERSION

        # Nothing retries on its own, so every attempt is the player running the command again. Reaching this many
        # means they have hit the same wall five times, which is no longer a transient one they can wait out.
        MAX_DELIVERY_ATTEMPTS = 5

        # What a delivery form may decide about a vehicle. Everything else on a claim's entry belongs to the admin who
        # configured the package.
        DELIVERY_CHOICE_KEYS = %i[spawn_location territory_id pin_code].freeze

        # Spawn locations that require input from the player that we can't easily get from a Discord interaction: where
        # they want their vehicle, or which territory's virtual garage to add it to.
        WEBSITE_ONLY_LOCATIONS = %w[player_decides virtual_garage].freeze

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
          check_for_discord_deliverable!(claim)

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

        # Requests can also be accepted from the website's My Requests page. Either way, the player hasn't given any
        # input about their vehicles, so this is treated as a Discord delivery.
        def on_request_accepted
          response = deliver_reward!(from_website: false)

          embed =
            if target_server.reward_vehicles_supported?
              response.embed
            else
              response.to_h
            end

          reply(embed_from_message!(embed))

          return if @held_vehicles.blank?

          # The server's receipt only covers what it was sent
          vehicles = describe_vehicles(@held_vehicles).join_map(", ") { |vehicle| "`#{vehicle.display_name}`" }

          reply(
            ESM::Embed.build(
              :info,
              description: I18n.t(
                "commands.reward.messages.held_for_website",
                user: current_user.mention,
                vehicles:,
                url: server_url(target_server)
              )
            )
          )
        end

        # The page reads the claim back out of the database itself, so the reply carries only what the row cannot say
        # afterwards: how the attempt went, and any failure that was dropped rather than kept for a retry.
        def on_website_execute
          response = deliver_reward!(from_website: true)

          reply(state: response.state, failures: failure_details(response))
        end

        module V1
          #
          # A v1 server was handed its reward contents when it connected and delivers those, whatever this side says
          # about them since. Everything the command grew on the way to v2 describes something it was never told
          # about: named packages it cannot look up, and a claim it has no way to leave anything in.
          #
          # @return [void]
          #
          def on_execute
            check_for_pending_request!

            # There is one reward here and it has no name, so a code is a code that does not exist. Answering with the
            # default instead would hand them something other than what they asked for and say nothing about it.
            if arguments.reward_id.present?
              raise_error!(:incorrect_reward_id, user: current_user, reward_id: arguments.reward_id)
            end

            package = target_server.server_rewards.enabled.default.first
            check_for_reward!(package)
            check_for_reward_items!(package)

            # The class skips the framework's cooldown action because a package owns its own. There are no packages
            # here, so this is the command's own cooldown, checked by hand for the same reason.
            check_for_cooldown!

            add_request(
              to: current_user,
              description: I18n.t(
                "commands.reward_v1.request_description",
                user: current_user.mention,
                server: target_server.server_id
              )
            )

            # Ignore PM channels to avoid double messages
            return if current_channel.pm?

            reply(
              ESM::Embed.build(
                :success,
                description: I18n.t("commands.request.check_pm", user: current_user.mention)
              )
            )
          end

          def on_response
            # Nothing was owed until the server said it handed something over, and a v1 delivery is all or nothing
            create_or_update_cooldown

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

        #
        # The package being claimed. Deliberately not gated on the server's version: which package a player picked is
        # settled entirely here, and the extension is only ever handed the contents. Gating it meant a named package
        # silently became the default one on an older server, which then answered with the default's cooldown.
        #
        # @return [ESM::ServerReward, nil] nil when no package has that ID, or the one that does has been disabled
        #
        def server_reward
          @server_reward ||=
            if arguments.reward_id.present?
              target_server.server_rewards.enabled.find_by(reward_id: arguments.reward_id)
            else
              target_server.server_rewards.enabled.default.first
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
            base << I18n.t("commands.reward.request_descriptions.player_poptabs", value: value.to_poptab)
          end

          if (value = contents.locker_poptabs).positive?
            base << I18n.t("commands.reward.request_descriptions.locker_poptabs", value: value.to_poptab)
          end

          if (value = contents.respect).positive?
            base << I18n.t("commands.reward.request_descriptions.respect", value:)
          end

          if (value = contents.items).present?
            value = value.join_map("\n") { |item| "#{item.quantity}x - #{item.display_name}" }
            base << I18n.t("commands.reward.request_descriptions.items", value:)
          end

          # Below the minimum version vehicles are not part of the reward, so the player is not told to expect any
          if target_server.reward_vehicles_supported? && (value = contents.vehicles).present?
            value = value.join_map("\n") do |vehicle|
              location =
                if website_only?(vehicle)
                  "claim on the server's dashboard"
                else
                  "spawned nearby"
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
            check_for_delivery_in_progress!(claim)
            check_for_exhausted_claim!(claim)
          end

          claim
        end

        #
        # Refuses a Discord redemption when everything in it is a vehicle that requires the player's input. Otherwise
        # the player would confirm in their DMs for a delivery that gives them nothing.
        #
        # @param reward [ESM::ServerReward, ESM::ServerRewardClaim] the package or claim being redeemed
        #
        # @return [void]
        #
        def check_for_discord_deliverable!(reward)
          return unless target_server.reward_vehicles_supported?

          contents = reward.contents
          return if contents.player_poptabs.positive? || contents.locker_poptabs.positive? || contents.respect.positive?
          return if contents.items.present?
          return unless contents.vehicles.present? && contents.vehicles.all? { |vehicle| website_only?(vehicle) }

          raise_error!(:website_only, user: current_user, url: server_url(target_server))
        end

        # Accepts a stored vehicle hash or a described one
        def website_only?(vehicle)
          WEBSITE_ONLY_LOCATIONS.include?(vehicle.to_h[:spawn_location])
        end

        def check_for_exhausted_claim!(claim)
          return unless claim.failed?

          raise_error!(:claim_exhausted, user: current_user, attempts: MAX_DELIVERY_ATTEMPTS)
        end

        #
        # Refuses a claim that is already on its way. A second attempt against a live delivery would hand the same
        # package over twice, and both surfaces can start one.
        #
        # Every delivery settles this state before it returns, whether the server answered, refused, or never replied,
        # so a claim is only ever found here while one is genuinely running.
        #
        # @param claim [ESM::ServerRewardClaim]
        #
        # @return [void]
        #
        def check_for_delivery_in_progress!(claim)
          return unless claim.in_flight?

          raise_error!(:delivery_in_progress, user: current_user)
        end

        #
        # Hands the player whatever they are owed and records what came back. Both surfaces run this; they differ only
        # in how they report it, since Discord answers with an embed the extension built and the website answers with
        # something its own page can render.
        #
        # @param from_website [Boolean] whether the player has given input about their vehicles. From Discord, vehicles
        #   that require it are held on the claim for the website.
        #
        # @return [ESM::Message::Data] the extension's response data
        #
        def deliver_reward!(from_website:)
          reward = load_and_check_claim!
          check_for_discord_deliverable!(reward) unless from_website

          is_package = reward.is_a?(ESM::ServerReward)

          # Below the minimum version vehicles are not part of the reward at all. Holding them on a claim until the
          # server updates would keep the player from every other package on it in the meantime.
          vehicles_supported = target_server.reward_vehicles_supported?

          # Resolved before the package becomes a claim. A form that no longer lines up should not leave the player
          # holding a mailbox they have to work through in place of a package they could simply redeem again.
          vehicles = delivery_vehicles(is_package ? reward.reward_vehicles : reward.vehicles) if vehicles_supported

          # The server would refuse these, and each refusal would count as a failed attempt the player can't fix from
          # Discord
          @held_vehicles = []
          if vehicles_supported && !from_website
            @held_vehicles, vehicles = vehicles.partition { |vehicle| website_only?(vehicle) }
          end

          # A claim row is where a partial delivery lives, so the package becomes one before it is attempted
          claim = is_package ? create_claim(reward, vehicles_supported:) : reward

          # The extension resolves display names off its own config, so it only needs the raw stored shapes
          data = {
            items: claim.items,
            locker: claim.locker_poptabs,
            money: claim.player_poptabs,
            respect: claim.respect
          }

          # An older server is never told about vehicles, so it cannot report any back and a claim that somehow holds
          # some settles without them
          data[:vehicles] = vehicles if vehicles_supported

          claim.update!(state: :in_flight)

          begin
            response = call_sqf_function!("ESMs_command_reward", **data).data
          rescue ESM::Exception::ExtensionError, ESM::Exception::ServerNotConnected
            # Nothing was given. The server's only two refusals - an account it has never seen, and a player who
            # is not in game and alive - are both checked before it delivers anything, and a call that never left never
            # reached them at all. A package that only became a claim to be attempted leaves nothing behind; otherwise
            # a player could stock every server they have never joined with a claim nobody can deliver.
            rollback_claim!(claim, created: is_package)

            raise
          rescue ESM::Exception::RequestTimeout
            # The one outcome nobody knows. Retrying could redeem the package twice, so the claim stops here and
            # waits for an admin, who can see the attempt and decide.
            claim.interrupt!("the server never answered")

            raise_error!(:delivery_stalled, user: current_user)
          end

          settle_claim!(claim, response, held_vehicles: @held_vehicles)

          response
        end

        #
        # Undoes an attempt that delivered nothing, leaving the player exactly where they started.
        #
        # Only a refusal means this much. An attempt that timed out may well have landed, so that one is settled as
        # failed instead and an admin decides what it was.
        #
        # @param claim [ESM::ServerRewardClaim] the claim that was just attempted
        # @param created [Boolean] whether this attempt is what created it
        #
        # @return [void]
        #
        def rollback_claim!(claim, created:)
          return claim.destroy! if created

          claim.update!(state: :waiting)
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

        # Two redemptions started together both will find no claim and both try to create one. The unique index on the
        # server and player is what settles it, and the one that loses is a player whose reward is already on its way.
        def create_claim(reward, vehicles_supported:)
          build_claim(reward, vehicles_supported:)
        rescue ActiveRecord::RecordNotUnique
          raise_error!(:delivery_in_progress, user: current_user)
        end

        def build_claim(reward, vehicles_supported:)
          ESM::ServerRewardClaim.create!(
            server_id: target_server.id,
            user_id: current_user.id,
            reward_id: reward.reward_id,
            player_poptabs: reward.player_poptabs,
            locker_poptabs: reward.locker_poptabs,
            respect: reward.respect,
            items: reward.reward_items,
            vehicles: vehicles_supported ? reward.reward_vehicles : [],
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
        # reported as a failure but cannot be retried, so it is dropped and the claim can still settle. The same goes
        # for vehicles an older server was never sent.
        #
        # Vehicles held for the website stay owed without counting an attempt. The server never tried them, and the
        # attempt limit is for repeated failures, not for input we couldn't ask for.
        #
        # @param claim [ESM::ServerRewardClaim] the claim that was just attempted
        # @param result [ESM::Message::Data] the extension's response data
        # @param held_vehicles [Array<Hash>] vehicles held for the website instead of being sent
        #
        # @return [void]
        #
        def settle_claim!(claim, result, held_vehicles: [])
          undelivered_items = result.undelivered_items.presence || {}
          refused_vehicles = result.undelivered_vehicles.presence || []
          undelivered_vehicles = refused_vehicles + held_vehicles

          if undelivered_items.blank? && undelivered_vehicles.blank?
            start_package_cooldown(claim)

            return claim.destroy!
          end

          attempted = undelivered_items.present? || refused_vehicles.present?
          attempt_count = attempted ? claim.attempt_count + 1 : claim.attempt_count

          held_failures = describe_vehicles(held_vehicles).map do |vehicle|
            {bucket: "vehicles", name: vehicle.display_name, reason: I18n.t("commands.reward.held_for_website_reason")}
          end

          # No cooldown on a partial. The player still has an unfinished claim, and the cooldown gates issuing a new
          # package, not finishing this one.
          claim.update!(
            player_poptabs: 0,
            locker_poptabs: 0,
            respect: 0,
            items: undelivered_items,
            vehicles: undelivered_vehicles,
            state: (attempt_count >= MAX_DELIVERY_ATTEMPTS) ? :failed : :waiting,
            state_details: {failures: failure_details(result) + held_failures},
            attempt_count:,
            last_attempt_at: attempted ? Time.current : claim.last_attempt_at
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
