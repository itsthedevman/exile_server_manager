# frozen_string_literal: true

# The local-only impersonation route: GET /dev/login/:discord_id. It exists so local browsing and
# browser-driven tests can reach authenticated pages without the Discord OAuth round trip. The route
# itself is gated on `Rails.env.local?`, which is true under test, so these specs can exercise it.
RSpec.describe "Dev::Sessions", type: :request do
  let(:user) { create(:user) }

  describe "GET create" do
    it "signs in the user and lands on the root path" do
      get "/dev/login/#{user.discord_id}"

      expect(response).to redirect_to(root_path)
      expect(controller.current_user).to eq(user)
    end

    it "honors return_to so a test can deep-link straight into a page" do
      get "/dev/login/#{user.discord_id}", params: {return_to: "/account/edit"}

      expect(response).to redirect_to("/account/edit")
    end

    it "lists the known users when the discord_id doesn't match anyone" do
      user

      get "/dev/login/nope"

      expect(response).to have_http_status(:not_found)
      expect(response.body).to include("No user with discord_id \"nope\"")
      expect(response.body).to include(user.discord_id)
    end
  end
end
