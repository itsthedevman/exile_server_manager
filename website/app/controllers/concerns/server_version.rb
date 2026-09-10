# frozen_string_literal: true

##
# Gates a server's player surfaces on the extension version they were built against.
#
module ServerVersion
  extend ActiveSupport::Concern

  # Everything a player can do from a server's pages runs through SQF that shipped with this version. An older server
  # passes the connection check happily and then fails somewhere further in, which reads to a player as a broken
  # website rather than a server that needs updating.
  MINIMUM_SERVER_VERSION = "2.1.0"

  included do
    helper_method :server_supported?
  end

  private

  ##
  # Whether this server is new enough for the surfaces built on top of it.
  #
  # Never enforced locally. A development extension reports whatever is currently built rather than whatever was last
  # released, so holding it to a released version number would mean bumping that number before the release is ready.
  #
  # @return [Boolean]
  #
  def server_supported?
    return true if Rails.env.local?

    !!current_server&.version?(MINIMUM_SERVER_VERSION)
  end

  ##
  # Refuses an action that would reach a server too old to answer it.
  #
  # Only for the acting controllers. A page that merely renders should say why instead, since the person most likely
  # to be looking at it is the one who can go update the server.
  #
  # @return [void]
  #
  def require_supported_server!
    return if server_supported?

    render_command_denied(outdated_server_message)
  end

  ##
  # The same copy the dashboard shows, so a player who acts anyway is told the same thing the page told them, and an
  # admin still gets the version numbers rather than being talked to like someone who cannot fix it.
  #
  # @return [String]
  #
  def outdated_server_message
    notice = helpers.server_unsupported_notice(current_server)

    helpers.server_manageable?(current_server) ? notice.admin_message : notice.player_message
  end
end
