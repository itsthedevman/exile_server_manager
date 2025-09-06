# frozen_string_literal: true

module Api
  class UsersController < ApiController
    MAX_BATCH_SIZE = 100

    #
    # GET /api/users
    #
    # Batch lookup users by steam_uids or discord_ids
    #
    # @param steam_uids [String, Array] JSON array or array of Steam UIDs
    # @param discord_ids [String, Array] JSON array or array of Discord IDs
    #
    def index
      users = []

      if params[:steam_uids].present?
        users += lookup_by_steam_uids(params[:steam_uids])
      end

      if params[:discord_ids].present?
        users += lookup_by_discord_ids(params[:discord_ids])
      end

      render json: users
    end

    #
    # GET /api/users/:id
    #
    # Lookup a single user by Discord ID
    #
    # @param discord_id [String] The Discord ID to query
    #
    def show
      discord_id = params[:id]
      user = ESM::User.find_by_discord_id(discord_id)

      render json: {
        discord_id: user&.discord_id || discord_id,
        steam_uid: user&.steam_uid
      }
    end

    private

    def lookup_by_steam_uids(steam_uids_input)
      steam_uids = parse_id_array(steam_uids_input)
      validate_batch_size!(steam_uids, "steam_uids")

      # Fetch all users in one query
      user_mapping = ESM::User
        .where(steam_uid: steam_uids)
        .pluck(:steam_uid, :discord_id)
        .to_h

      # Return results for all requested UIDs, even if not found
      steam_uids.map do |steam_uid|
        {
          steam_uid: steam_uid,
          discord_id: user_mapping[steam_uid]
        }
      end
    end

    def lookup_by_discord_ids(discord_ids_input)
      discord_ids = parse_id_array(discord_ids_input)
      validate_batch_size!(discord_ids, "discord_ids")

      # Fetch all users in one query
      user_mapping = ESM::User
        .where(discord_id: discord_ids)
        .pluck(:discord_id, :steam_uid)
        .to_h

      # Return results for all requested IDs, even if not found
      discord_ids.map do |discord_id|
        {
          discord_id: discord_id,
          steam_uid: user_mapping[discord_id]
        }
      end
    end

    def parse_id_array(input)
      return input if input.is_a?(Array)

      input.to_a || []
    end

    def validate_batch_size!(array, field_name)
      return if array.size <= MAX_BATCH_SIZE

      payload_too_large!("Exceeded maximum batch size of #{MAX_BATCH_SIZE} for #{field_name}")
    end
  end
end
