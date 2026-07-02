# frozen_string_literal: true

# The server hub: a role-adaptive dashboard for a single server, reached at
# /servers/:id. Players land here from their favorites. The body is a grid of
# feature cards (My Player now; gambling, rewards, and more later), each gated
# on whether its command is enabled for the server's community.
class ServersController < AuthenticatedController
  def show
    return not_found! if current_server.nil?

    render locals: {current_server:}
  end

  private

  def current_server
    @current_server ||= ESM::Server.find_by_public_id(params[:id])
  end
end
