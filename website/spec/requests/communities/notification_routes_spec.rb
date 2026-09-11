# frozen_string_literal: true

RSpec.describe "Communities::NotificationRoutes", type: :request do
  let(:community) { create(:community) }
  let(:user) { create(:user) }
  let(:modifiable) { true }

  before do
    sign_in user
    allow_any_instance_of(ESM::Community).to receive(:modifiable_by?).and_return(modifiable)
  end

  def route_for(destination, **attrs)
    create(:user_notification_route, destination_community: destination, **attrs)
  end

  describe "GET index" do
    it "renders the community's routes" do
      route_for(community)

      get "/communities/#{community.public_id}/notification_routes"

      expect(response).to have_http_status(:ok)
    end

    context "when the viewer cannot modify the community" do
      let(:modifiable) { false }

      it "is not found" do
        get "/communities/#{community.public_id}/notification_routes"

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "PATCH update" do
    def patch_update(route, enabled: false)
      patch "/communities/#{community.public_id}/notification_routes/#{route.public_id}",
        params: {enabled:},
        as: :turbo_stream
    end

    it "toggles the community's own accepted route" do
      route = route_for(community, enabled: true)

      patch_update(route)

      expect(response).to have_http_status(:ok)
      expect(route.reload.enabled).to be(false)
    end

    context "when the viewer cannot modify the community" do
      let(:modifiable) { false }

      it "is not found" do
        route = route_for(community, enabled: true)

        patch_update(route)

        expect(response).to have_http_status(:not_found)
      end
    end

    it "is not found for a route this community has not accepted yet" do
      route = route_for(community, enabled: true, community_accepted: false)

      patch_update(route)

      expect(response).to have_http_status(:not_found)
    end

    it "is not found for a route belonging to another community" do
      foreign_route = route_for(create(:community), enabled: true)

      patch_update(foreign_route)

      expect(response).to have_http_status(:not_found)
      expect(foreign_route.reload.enabled).to be(true)
    end
  end

  describe "PATCH accept" do
    def patch_accept(ids)
      patch "/communities/#{community.public_id}/notification_routes/accept", params: {ids: ids.to_json}
    end

    it "accepts the community's own pending routes" do
      route = route_for(community, community_accepted: false)

      patch_accept([route.public_id])

      expect(response).to redirect_to(community_notification_routes_path)
      expect(route.reload.community_accepted).to be(true)
    end

    context "when the viewer cannot modify the community" do
      let(:modifiable) { false }

      it "is not found" do
        route = route_for(community, community_accepted: false)

        patch_accept([route.public_id])

        expect(response).to have_http_status(:not_found)
      end
    end

    # No partial accept: an id list naming even one route outside this community 404s the whole batch rather than
    # silently accepting the subset that matched.
    it "is not found when one of the ids belongs to another community, and accepts none of them" do
      own_route = route_for(community, community_accepted: false)
      foreign_route = route_for(create(:community), community_accepted: false)

      patch_accept([own_route.public_id, foreign_route.public_id])

      expect(response).to have_http_status(:not_found)
      expect(own_route.reload.community_accepted).to be(false)
      expect(foreign_route.reload.community_accepted).to be(false)
    end
  end

  describe "PATCH decline" do
    def patch_decline(ids)
      patch "/communities/#{community.public_id}/notification_routes/decline", params: {ids: ids.to_json}
    end

    it "declines the community's own pending routes" do
      route = route_for(community, community_accepted: false)

      expect { patch_decline([route.public_id]) }.to change(ESM::UserNotificationRoute, :count).by(-1)

      expect(response).to redirect_to(community_notification_routes_path)
    end

    context "when the viewer cannot modify the community" do
      let(:modifiable) { false }

      it "is not found" do
        route = route_for(community, community_accepted: false)

        expect { patch_decline([route.public_id]) }.not_to change(ESM::UserNotificationRoute, :count)

        expect(response).to have_http_status(:not_found)
      end
    end

    it "is not found when one of the ids belongs to another community, and declines none of them" do
      own_route = route_for(community, community_accepted: false)
      foreign_route = route_for(create(:community), community_accepted: false)

      expect {
        patch_decline([own_route.public_id, foreign_route.public_id])
      }.not_to change(ESM::UserNotificationRoute, :count)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE destroy" do
    def delete_route(route)
      delete "/communities/#{community.public_id}/notification_routes/#{route.public_id}",
        as: :turbo_stream
    end

    it "removes the community's own route" do
      route = route_for(community)

      expect { delete_route(route) }.to change(ESM::UserNotificationRoute, :count).by(-1)
    end

    context "when the viewer cannot modify the community" do
      let(:modifiable) { false }

      it "is not found" do
        route = route_for(community)

        expect { delete_route(route) }.not_to change(ESM::UserNotificationRoute, :count)

        expect(response).to have_http_status(:not_found)
      end
    end

    it "is not found for a route belonging to another community" do
      foreign_route = route_for(create(:community))

      expect { delete_route(foreign_route) }.not_to change(ESM::UserNotificationRoute, :count)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE destroy_many" do
    def delete_many(ids)
      delete "/communities/#{community.public_id}/notification_routes/destroy_many", params: {ids:}
    end

    it "removes the community's own selected routes" do
      routes = [route_for(community, channel_id: "111"), route_for(community, channel_id: "222")]

      expect { delete_many(routes.map(&:public_id)) }.to change(ESM::UserNotificationRoute, :count).by(-2)

      expect(response).to redirect_to(community_notification_routes_path)
    end

    context "when the viewer cannot modify the community" do
      let(:modifiable) { false }

      it "is not found and destroys nothing" do
        route = route_for(community)

        expect { delete_many([route.public_id]) }.not_to change(ESM::UserNotificationRoute, :count)

        expect(response).to have_http_status(:not_found)
      end
    end

    # Unlike accept/decline, destroy_many does not compare routes.size against ids.size, so a mixed request quietly
    # destroys only the ones that matched instead of 404ing the whole batch. Documented here as today's actual
    # behavior (not an IDOR - the foreign route is never touched) so a future change to match its siblings is a
    # deliberate decision rather than a silent regression either direction.
    it "destroys only the ids that belong to this community and leaves the foreign one alone" do
      own_route = route_for(community)
      foreign_route = route_for(create(:community))

      expect {
        delete_many([own_route.public_id, foreign_route.public_id])
      }.to change(ESM::UserNotificationRoute, :count).by(-1)

      expect(response).to redirect_to(community_notification_routes_path)
      expect { own_route.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect(foreign_route.reload).to be_persisted
    end
  end
end
