# frozen_string_literal: true

class ChannelsController < AuthenticatedController
  def index
    # Do this before calling any current_community related code
    convert_community_id

    channels =
      if params[:user]
        # We're filtering by the channels we have access to.
        # Permission checking is handled by the bot.
        not_found! if current_community.nil?

        current_community.player_channels(current_user)
      else
        # If we're trying to view all channels, we have to have modification permissions
        check_for_community_access!

        current_community.channels
      end

    if params[:slim_select]
      channels = helpers.group_data_from_collection_for_slim_select(
        channels,
        ->(category) { category[:name] },
        ->(channel) { "#{channel[:id]}:#{channel[:name]}" },
        ->(channel) { channel[:name] },
        placeholder: true,
        select_all: true
      )
    end

    render json: {content: {channels:}}
  end

  private

  # Situation:
  #   I need to hit this controller, but I don't have a good way to give the client access
  #   to every community's public ID that doesn't require sharing every community's public ID.
  #   However, the client already has access to the community's community ID, I had an idea.
  #
  # Solution:
  #   Since this controller needs to switch access control checks based on flags, I opted to
  #   allow only this route to accept passing in a community ID instead of a public ID. For the
  #   low price of an extra query, I don't have to require the client to have access to every
  #   public ID, or providing a "public" lookup API endpoint.
  #
  def convert_community_id
    params[:community_community_id] = ESM::Community.with_community_id(
      params[:community_community_id]
    ).pick(:public_id)
  end
end
