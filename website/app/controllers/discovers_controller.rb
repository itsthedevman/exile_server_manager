# frozen_string_literal: true

class DiscoversController < ApplicationController
  def show
    return if params[:q].blank?

    search_term = params.require(:q)
    search_term_wildcard = "%#{search_term}%"

    communities = ESM::Community
      .select(:community_id, :community_name)
      .left_joins(:servers)
      .where(
        <<~SQL,
          communities.community_id ilike :term OR
          communities.community_name ilike :term OR
          communities.guild_id ilike :term OR
          servers.server_id ilike :term OR
          servers.server_name ilike :term OR
          servers.server_ip ilike :term
        SQL
        term: search_term_wildcard
      )
      .distinct
      .order(:community_id)

    servers = ESM::Server
      .select(:server_id, :server_name, :server_ip, :server_port)
      .joins(:community)
      .where(server_visibility: :public)
      .where(
        <<~SQL,
          servers.server_id ilike :term OR
          servers.server_name ilike :term OR
          servers.server_ip ilike :term OR
          communities.community_id ilike :term OR
          communities.community_name ilike :term OR
          communities.guild_id ilike :term
        SQL
        term: search_term_wildcard
      )
      .distinct
      .order(:server_id)

    render locals: {communities:, servers:}
  end
end
