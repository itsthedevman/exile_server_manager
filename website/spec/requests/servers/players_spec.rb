# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Servers::Players", type: :request do
  let(:community) { create(:community) }
  let(:server) { create(:server, community:) }
  let(:user) { create(:user) }

  before do
    sign_in user

    # The player snapshot and the online check are NATS reads against the game
    # server; stub both so the pages render their offline state without the bot.
    allow_any_instance_of(ESM::Server).to receive(:player_info).and_return(nil)
    allow_any_instance_of(ESM::Server).to receive(:connected?).and_return(false)
  end

  # The full /me page renders the whole server-hub shell, which fans out into more
  # game-server reads than a controller spec should stub. summary (the lazy card)
  # exercises the same load path in isolation; the auth guard is checked on /me.
  it "renders the lazy summary card" do
    get "/servers/#{server.public_id}/players/summary"

    expect(response).to have_http_status(:ok)
  end

  it "requires a signed-in user" do
    sign_out user
    get "/servers/#{server.public_id}/players/me"

    expect(response).to redirect_to("/login")
  end
end
