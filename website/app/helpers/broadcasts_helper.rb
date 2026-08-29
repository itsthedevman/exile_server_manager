# frozen_string_literal: true

module BroadcastsHelper
  # Every field but :value is copy the audience selector swaps in when the choice changes. Rendering all of it here
  # rather than assembling sentences in JavaScript keeps the wording, and its translations, in one place.
  AudienceOption = Data.define(:value, :label, :recipients, :preview_title, :summary)

  ##
  # The audience choices for a community's broadcast, each carrying how many people it would reach.
  #
  # The counts come from the same resolver the command delivers with, so the number an admin is shown is the number
  # that gets messaged. "Every server" is a deduplicated union rather than a total, so it is normally smaller than the
  # per-server counts added together and never larger.
  #
  # @param community [ESM::Community]
  #
  # @return [Array<AudienceOption>]
  #
  def broadcast_audiences(community)
    servers = community.servers.sort_by(&:server_id)

    options = servers.map { |server| broadcast_audience(community, server.public_id, server.server_id, [server]) }
    return options if servers.size < 2

    options + [broadcast_audience(community, "all", "Every server", servers)]
  end

  private

  def broadcast_audience(community, value, label, servers)
    recipients = ESM::Command::Server::Broadcast::Audience.for(servers).size

    AudienceOption.new(
      value:,
      label:,
      recipients:,
      preview_title: broadcast_preview_title(community, servers),
      summary: broadcast_recipient_summary(recipients, servers)
    )
  end

  # The embed title players will actually see, built from the same translation the command sends with.
  def broadcast_preview_title(community, servers)
    I18n.t(
      "commands.broadcast.broadcast_embed.title",
      community_name: community.community_name,
      server_ids: servers.map { |server| "`#{server.server_id}`" }.to_sentence
    )
  end

  # A broadcast reaches the players ESM has seen, which is not the same as the players who have been on the server -
  # ESM only learns about someone once they run a command for it. The zero state says that rather than claiming the
  # server has never been played on, which is a stronger thing than ESM is in any position to know.
  def broadcast_recipient_summary(recipients, servers)
    scope = (servers.size > 1) ? "your servers" : "this server"
    return "No one has used ESM on #{scope} yet, so there is nobody to send to." if recipients.zero?

    "This sends a Discord message to #{pluralize(recipients, "player")}."
  end
end
