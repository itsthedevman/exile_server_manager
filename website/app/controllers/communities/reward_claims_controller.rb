# frozen_string_literal: true

module Communities
  class RewardClaimsController < AuthenticatedController
    include Commands

    before_action :check_for_community_access!

    # Whatever needs a person comes first. A failed claim is a player who cannot redeem anything else on that server
    # until someone here does something, and an in-flight one is an attempt that never reported back.
    STATE_ORDER = %w[failed in_flight waiting].freeze

    # Discord's own cap on how long one embed field's value may be
    EMBED_FIELD_LIMIT = 1024

    # Left free at the end of a field so the line saying what was cut has somewhere to go
    TRUNCATION_ROOM = 40

    def index
      render locals: listing_locals
    end

    def new
      render locals: claim_form_locals
    end

    def edit
      claim = find_claim
      not_found! if claim.nil?

      render locals: claim_form_locals(claim:, submitted: submitted_from(claim))
    end

    ##
    # Rewrites what a player is owed, rather than adding to it.
    #
    # Someone arriving at a claim to take one broken vehicle back out of it means the form to say what the claim
    # holds now, which is the opposite of what a grant means by the same fields.
    #
    # @return [void]
    #
    def update
      claim = find_claim
      not_found! if claim.nil?

      contents = claim_contents
      error = claim_contents_error(claim.server, contents)
      return render_claim_error(error) if error

      apply_claim_edit(claim, contents)

      render turbo_stream: [
        listing_stream,
        hide_modal("#reward_claim_modal"),
        create_success_toast("#{claim_label(claim)} has been updated")
      ]
    end

    ##
    # Hands a player something they never asked for.
    #
    # It merges into whatever they are already owed rather than being refused by the one-claim cap: the cap exists so
    # a player cannot stockpile redemptions, and an admin handing out a prize is not that.
    #
    # @return [void]
    #
    def create
      @current_server = grant_server
      return render_claim_error("Pick the server this reward is on.") if current_server.nil?

      return unless check_for_command_access("info")

      player = grant_player
      return if performed?

      contents = claim_contents
      error = claim_contents_error(current_server, contents)
      return render_claim_error(error) if error

      server = current_server
      claim = grant_into_claim(server, player, contents)
      messaged = notify_granted_player(claim, server, player)

      render turbo_stream: [
        listing_stream,
        hide_modal("#reward_claim_modal"),
        create_success_toast(grant_outcome_message(server, player, messaged))
      ]
    end

    def confirm_destroy
      claim = find_claim
      not_found! if claim.nil?

      render locals: {claim:}
    end

    ##
    # Lets the player try for a stopped claim again.
    #
    # The attempts go back with it. A claim stops once it has spent all of them, so leaving the count where it is
    # would have the next attempt stop it again straight away.
    #
    # @return [void]
    #
    def release
      claim = find_claim
      not_found! if claim.nil?

      # Every other state is one the reward command picks up on its own, so there is nothing here to allow.
      unless claim.failed?
        return render turbo_stream: create_info_toast("#{claim_label(claim)} can already be delivered")
      end

      claim.update!(state: :waiting, attempt_count: 0)

      render turbo_stream: [
        listing_stream,
        create_success_toast("#{claim_label(claim)} can be delivered again")
      ]
    end

    def destroy
      claim = find_claim
      not_found! if claim.nil?

      label = claim_label(claim)
      claim.destroy!

      render turbo_stream: [
        listing_stream,
        hide_modal("#reward_claim_modal"),
        create_success_toast("#{label} has been deleted")
      ]
    end

    private

    ##
    # Every claim owed by a server this community owns, urgent first.
    #
    # The mailbox is capped at one row per player per server and a delivered claim is deleted outright, so the whole
    # set is what an admin came to look at rather than a page of it.
    #
    # @return [Array<ESM::ServerRewardClaim>]
    #
    def listed_claims
      claims = ESM::ServerRewardClaim
        .where(server_id: current_community.servers.select(:id))
        .includes(:server, :user)

      claims.sort_by { |claim| [STATE_ORDER.index(claim.state), claim.created_at] }
    end

    def listing_locals
      claims = listed_claims

      {
        claims:,
        player_options: player_options(claims),
        server_options: server_options(claims)
      }
    end

    def listing_stream
      turbo_stream.replace(
        "reward_claims_card",
        partial: "communities/reward_claims/listing",
        locals: listing_locals
      )
    end

    # Only the players and servers that actually have a claim. A select offering a name that matches nothing is a
    # filter that can only empty the table.
    def player_options(claims)
      claims.filter_map(&:user).uniq(&:id).sort_by { |user| user.username.to_s.downcase }
    end

    def server_options(claims)
      claims.filter_map(&:server).uniq(&:id).sort_by(&:server_id)
    end

    ##
    # The claim addressed by the URL, which names it by the pair its unique index is built on rather than by an id
    # the row does not have.
    #
    # @return [ESM::ServerRewardClaim, nil]
    #
    def find_claim
      # Nesting prefixes a resource's own param with its parent's name, the same as it does for the community
      server = current_community.servers.find_by(public_id: params[:server_server_id])
      return if server.nil?

      user = ESM::User.find_by(discord_id: params[:user_id])
      return if user.nil?

      ESM::ServerRewardClaim.find_by(server_id: server.id, user_id: user.id)
    end

    def claim_label(claim)
      helpers.reward_claim_label(claim)
    end

    ##################################################################################################
    # Writing a claim, whether it is being started or rewritten
    ##################################################################################################

    def claim_form_locals(claim: nil, submitted: blank_submission)
      {servers: grantable_servers, claim:, submitted:}
    end

    # A refusal answers with a toast and leaves the modal alone, so the only form this ever draws is a new one.
    def blank_submission
      {server_id: nil, player: nil, player_poptabs: 0, locker_poptabs: 0, respect: 0, items: [], vehicles: []}
        .to_datum
    end

    ##
    # Why the form was not accepted, without touching the form.
    #
    # Sending the form back would cost whoever is filling it in their cursor and every field they had already
    # answered, to tell them one of them is wrong. The modal stays exactly as they left it and the toast says what
    # to fix.
    #
    # @param message [String]
    #
    # @return [void]
    #
    def render_claim_error(message)
      render turbo_stream: create_error_toast(message), status: :unprocessable_content
    end

    # The server a write is being made against. Set by the action rather than read from the URL, because this page is
    # community wide and which server it is happens to be one of the answers the form gives.
    attr_reader :current_server

    # Claims only exist on a server whose owner has moved to the v2 UI, the same gate the package editor keys on.
    def grantable_servers
      current_community.servers.select(&:ui_v2?).sort_by(&:server_id)
    end

    def claim_params
      params.fetch(:reward_claim, ActionController::Parameters.new).permit(
        :server_id, :player, :player_poptabs, :locker_poptabs, :respect,
        items: [:classname, :quantity],
        vehicles: [:class_name, :spawn_location]
      )
    end

    # What the form opens on when an existing claim is being edited: everything the player is owed right now.
    def submitted_from(claim)
      {
        server_id: claim.server&.public_id,
        player: claim.user&.steam_uid,
        player_poptabs: claim.player_poptabs,
        locker_poptabs: claim.locker_poptabs,
        respect: claim.respect,
        items: claim.items.map { |classname, quantity| {classname: classname.to_s, quantity:}.to_datum },
        vehicles: claim.vehicles.map do |vehicle|
          {
            class_name: vehicle[:class_name].to_s,
            spawn_location: vehicle[:spawn_location].presence || "nearby"
          }.to_datum
        end
      }.to_datum
    end

    def grant_server
      grantable_servers.find { |server| server.public_id == claim_params[:server_id] }
    end

    ##
    # Why these contents cannot be written, when they cannot.
    #
    # @param server [ESM::Server] the server the claim is on
    # @param contents [Hash]
    #
    # @return [String, nil]
    #
    def claim_contents_error(server, contents)
      if contents[:vehicles].present? && !helpers.reward_packages_vehicles_supported?(server)
        return helpers.reward_packages_vehicles_unsupported_message(server)
      end

      return if claim_holds_something?(contents)

      "A reward has to hold something. Add currency, an item or a vehicle."
    end

    ##
    # Who the typed identifier names, if it names anybody this admin has business granting a reward to.
    #
    # The lookup runs against the game server before it answers, the same way the admin player pages do. Without
    # that, anybody who can open this form could type a Steam UID they found anywhere and read back the Discord
    # account behind it, for a player with no connection to their community at all.
    #
    # Renders the refusal itself, since there is one message for every way this can come up empty. Naming which way
    # it was is what turns the form into a way of asking whether an account exists.
    #
    # @return [ESM::User, nil]
    #
    def grant_player
      lookup = ESM::PlayerLookup.call(claim_params[:player])

      if lookup.blank?
        render_claim_error("Enter the player's Steam UID or Discord ID.")
        return
      end

      return render_claim_error(player_not_found_message) unless lookup.steam_uid?

      case known_to_server?(lookup.steam_uid)
      when nil
        return render_claim_error("#{current_server.server_id} is offline. Try again once it's back up.")
      when false
        return render_claim_error(player_not_found_message)
      end

      player = ESM::User.find_by_steam_uid(lookup.steam_uid)

      # They play here, so saying why nothing can be sent to them gives an admin something to act on and tells them
      # nothing they could not already see on their own player pages.
      if player.nil?
        render_claim_error("That player hasn't registered with ESM, so there's nowhere to deliver a reward.")
        return
      end

      player
    end

    # One message for every way the lookup comes up empty, so the form cannot be used to tell an account that exists
    # from one that does not.
    def player_not_found_message
      "We couldn't find that player on #{current_server.server_id}."
    end

    ##
    # Whether the game server knows this player.
    #
    # @param steam_uid [String]
    #
    # @return [Boolean, nil] nil when the server could not be asked
    #
    def known_to_server?(steam_uid)
      call_sync_command("info", arguments: {target: steam_uid}).present?
    rescue ESM::Service::API::RemoteError => e
      # info raises rather than returning nothing when it has no player to describe, so the command answering at all
      # means the answer is no. Connectivity was already settled by the access check above this.
      Rails.logger.info("[reward_claims#create] #{current_server.server_id} does not know that player: #{e.message}")
      false
    rescue ESM::Service::API::Unreachable => e
      Rails.logger.warn("[reward_claims#create] could not reach the bot: #{e.message}")
      nil
    end

    # Overrides Commands#render_command_denied. A denial answers the form the same way every other refusal does,
    # rather than replacing a region this page never named.
    def render_command_denied(message)
      render_claim_error(message)
    end

    def claim_contents
      permitted = claim_params

      {
        player_poptabs: permitted[:player_poptabs].to_i,
        locker_poptabs: permitted[:locker_poptabs].to_i,
        respect: permitted[:respect].to_i,
        items: granted_items(permitted),
        vehicles: granted_vehicles(permitted)
      }
    end

    # Symbol keys, because a stored claim's items come back symbol keyed and the merge has to line up with them
    # rather than land a second entry beside the one already there.
    def granted_items(permitted)
      Array(permitted[:items])
        .group_by_key(:classname)
        .transform_values { |rows| rows.sum { |row| row[:quantity].to_i } }
        .reject { |classname, quantity| classname.blank? || quantity < 1 }
        .transform_keys(&:to_sym)
    end

    def granted_vehicles(permitted)
      Array(permitted[:vehicles]).filter_map do |vehicle|
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

    # Mirrors ESM::ServerReward#rewards?, which is what decides whether there is anything to hand over at all
    def claim_holds_something?(contents)
      contents[:player_poptabs].positive? ||
        contents[:locker_poptabs].positive? ||
        contents[:respect].positive? ||
        contents[:items].present? ||
        contents[:vehicles].present?
    end

    ##
    # Adds the grant to whatever the player is already owed on that server.
    #
    # It merges rather than being refused by the one-claim cap. The cap is there so a player cannot stockpile
    # redemptions of their own; an admin handing out a prize is not what it was written against.
    #
    # @param server [ESM::Server]
    # @param player [ESM::User]
    # @param contents [Hash]
    #
    # @return [ESM::ServerRewardClaim]
    #
    def grant_into_claim(server, player, contents)
      claim = ESM::ServerRewardClaim.find_or_initialize_by(server_id: server.id, user_id: player.id)

      claim.player_poptabs += contents[:player_poptabs]
      claim.locker_poptabs += contents[:locker_poptabs]
      claim.respect += contents[:respect]

      # Items are keyed by class name, so the same one twice is one entry with a bigger number
      claim.items = claim.items.merge(contents[:items]) { |_class_name, owed, granted| owed + granted }
      claim.vehicles = claim.vehicles + contents[:vehicles]
      claim.state_details = claim_cleared_failures(claim, granted_buckets(contents))

      make_deliverable(claim)

      claim.save!
      claim
    end

    ##
    # Replaces what a claim holds with what the form says it holds now.
    #
    # @param claim [ESM::ServerRewardClaim]
    # @param contents [Hash]
    #
    # @return [void]
    #
    def apply_claim_edit(claim, contents)
      touched = edited_buckets(claim, contents)

      claim.player_poptabs = contents[:player_poptabs]
      claim.locker_poptabs = contents[:locker_poptabs]
      claim.respect = contents[:respect]
      claim.items = contents[:items]
      claim.vehicles = contents[:vehicles]
      claim.state_details = claim_cleared_failures(claim, touched)

      make_deliverable(claim)

      claim.save!
    end

    # Whichever buckets a grant put something into. A reason collected about the vehicles stops describing them the
    # moment another one lands beside them.
    def granted_buckets(contents)
      buckets = []
      buckets << "items" if contents[:items].present?
      buckets << "vehicles" if contents[:vehicles].present?
      buckets
    end

    # Whichever buckets an edit actually changed. Bumping the poptabs on a claim whose vehicle could not spawn leaves
    # that reason describing the same vehicle it always was.
    def edited_buckets(claim, contents)
      buckets = []
      buckets << "items" if claim.items != contents[:items]
      buckets << "vehicles" if claim.vehicles != contents[:vehicles]
      buckets
    end

    def claim_cleared_failures(claim, touched)
      failures = Array(claim.state_details[:failures])
      return claim.state_details if failures.empty? || touched.empty?

      {failures: failures.reject { |failure| touched.include?(failure[:bucket].to_s) }}
    end

    ##
    # Leaves the claim ready for the player, whatever state the write found it in.
    #
    # A delivery in progress is a delivery of what the claim held a moment ago, so a row still calling itself one
    # after an admin has rewritten it is describing something that is not happening. A stopped claim is one the
    # admin means the player to have, and it cannot be attempted while it is stopped.
    #
    # Only that stopped claim gets its attempts back. The ones an in-flight claim has spent were spent by deliveries
    # that really did finish.
    #
    # @param claim [ESM::ServerRewardClaim]
    #
    # @return [void]
    #
    def make_deliverable(claim)
      claim.attempt_count = 0 if claim.failed?
      claim.state = :waiting
    end

    ##
    # Tells the player something they never asked for is waiting.
    #
    # The one push the design allows, because this is the only claim nobody has a reason to go looking for. A bot
    # that cannot be reached does not undo the grant, it just means nobody was told about it yet.
    #
    # @return [Boolean] whether the message went out
    #
    def notify_granted_player(claim, server, player)
      Bot.send_message(channel_id: player.discord_id, message: grant_message(claim, server))
      true
    rescue ESM::Service::API::Unreachable, ESM::Service::API::RemoteError => e
      Rails.logger.warn("[reward_claims#create] could not message #{player.discord_id}: #{e.message}")
      false
    end

    def grant_message(claim, server)
      {
        title: "A reward is waiting for you",
        description: "An admin on #{server.community.community_id} has left you a reward on " \
          "`#{server.server_id}`. Claim it from that server's page on the ESM website, or run the reward " \
          "command in Discord.",
        color: :green,
        fields: grant_message_fields(claim.contents)
      }
    end

    ##
    # The contents as embed fields.
    #
    # Discord lays inline fields three to a row, so the currencies read across as one line the way the website's
    # receipt does, and the two lists take a row each underneath.
    #
    # @param contents [Datum]
    #
    # @return [Array<Hash>]
    #
    def grant_message_fields(contents)
      currencies = {
        "Poptabs" => contents.player_poptabs,
        "Locker" => contents.locker_poptabs,
        "Respect" => contents.respect
      }

      fields = currencies.filter_map do |name, amount|
        {name:, value: helpers.number_with_delimiter(amount), inline: true} if amount.positive?
      end

      if contents.items.present?
        lines = contents.items.map { |item| "#{item.quantity}x #{item.display_name}" }
        fields << {name: "Items", value: embed_list(lines)}
      end

      if contents.vehicles.present?
        lines = contents.vehicles.map do |vehicle|
          "#{vehicle.display_name} (#{helpers.reward_vehicle_destination(vehicle)})"
        end

        fields << {name: "Vehicles", value: embed_list(lines)}
      end

      fields
    end

    # A field value stops at EMBED_FIELD_LIMIT characters, and a claim somebody has piled sixty items into runs past
    # it. What does not fit is counted rather than dropped without saying so.
    def embed_list(lines)
      value = lines.join("\n")
      return value if value.length <= EMBED_FIELD_LIMIT

      kept = 0
      length = 0

      lines.each do |line|
        length += line.length + 1
        break if length > EMBED_FIELD_LIMIT - TRUNCATION_ROOM

        kept += 1
      end

      "#{lines.first(kept).join("\n")}\nand #{lines.size - kept} more"
    end

    def grant_outcome_message(server, player, messaged)
      granted = "#{player.username} has been granted a reward on #{server.server_id}"
      return granted if messaged

      "#{granted}, but they could not be messaged about it"
    end
  end
end
