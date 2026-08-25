# frozen_string_literal: true

RSpec.describe "Servers::Favorites", type: :request do
  let(:community) { create(:community) }
  let(:server) { create(:server, community:) }
  let(:user) { create(:user) }

  before { sign_in user }

  describe "POST /favorite" do
    it "favorites the server" do
      expect { post "/servers/#{server.public_id}/favorite", as: :turbo_stream }
        .to change { user.server_favorites.count }.by(1)

      expect(response).to have_http_status(:ok)
    end

    it "is idempotent - favoriting twice keeps a single row" do
      post "/servers/#{server.public_id}/favorite", as: :turbo_stream

      expect { post "/servers/#{server.public_id}/favorite", as: :turbo_stream }
        .not_to change { user.server_favorites.count }
    end

    it "404s an unknown server" do
      post "/servers/#{SecureRandom.uuid}/favorite", as: :turbo_stream

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /favorite" do
    it "removes the favorite" do
      user.server_favorites.create!(server:)

      expect { delete "/servers/#{server.public_id}/favorite", as: :turbo_stream }
        .to change { user.server_favorites.count }.by(-1)
    end
  end

  it "requires a signed-in user" do
    sign_out user
    post "/servers/#{server.public_id}/favorite", as: :turbo_stream

    expect(response).to redirect_to("/login")
  end
end
