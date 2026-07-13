# frozen_string_literal: true

require "rails_helper"

# The player-facing XM8 notification routing (/account/notification_routes).
# `create` reaches into the Discord bot (channel lookup + send_message) and the
# granular `destroy` re-groups route cards - both want their own dedicated pass.
# Covered here: the toggle, the bulk delete, and the scoping/auth guards.
RSpec.describe "Users::NotificationRoutes", type: :request do
  let(:community) { create(:community) }
  let(:user) { create(:user) }

  before { sign_in user }

  def route_for(owner, **attrs)
    create(:user_notification_route, user: owner, destination_community: community, **attrs)
  end

  describe "PATCH update" do
    it "toggles the caller's own accepted route" do
      route = route_for(user, enabled: true)

      patch "/account/notification_routes/#{route.public_id}", params: {enabled: false}, as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(route.reload.enabled).to be(false)
    end

    it "404s a route the community hasn't accepted yet" do
      route = route_for(user, community_accepted: false)

      patch "/account/notification_routes/#{route.public_id}", params: {enabled: false}, as: :turbo_stream

      expect(response).to have_http_status(:not_found)
    end

    it "404s another user's route" do
      route = route_for(create(:user))

      patch "/account/notification_routes/#{route.public_id}", params: {enabled: false}, as: :turbo_stream

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE destroy_many" do
    it "removes the caller's selected routes" do
      routes = [route_for(user, channel_id: "111"), route_for(user, channel_id: "222")]

      expect do
        delete "/account/notification_routes/destroy_many", params: {ids: routes.map(&:public_id)}, as: :turbo_stream
      end.to change { user.user_notification_routes.count }.by(-2)
    end

    it "404s when none of the ids belong to the caller" do
      other = route_for(create(:user))

      delete "/account/notification_routes/destroy_many", params: {ids: [other.public_id]}, as: :turbo_stream

      expect(response).to have_http_status(:not_found)
    end
  end

  it "requires a signed-in user" do
    sign_out user
    delete "/account/notification_routes/destroy_many", params: {ids: []}, as: :turbo_stream

    expect(response).to redirect_to("/login")
  end
end
