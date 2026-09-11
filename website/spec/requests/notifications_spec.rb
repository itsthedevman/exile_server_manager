# frozen_string_literal: true

RSpec.describe "Notifications", type: :request do
  let(:community) { create(:community, player_mode_enabled: false) }
  let(:user) { create(:user) }
  let(:modifiable) { true }

  # Community#create_notifications seeds one row per default notification on creation (community.rb:61,196), so
  # every community already has something to edit/update/destroy without a spec building its own. There is no
  # :notification factory in this suite; the seeded defaults stand in for it.
  let(:notification) { community.notifications.first }

  before do
    sign_in user
    allow_any_instance_of(ESM::Community).to receive(:modifiable_by?).and_return(modifiable)
  end

  describe "GET index" do
    it "renders the community's notifications" do
      get "/communities/#{community.public_id}/notifications"

      expect(response).to have_http_status(:ok)
    end

    context "when the viewer cannot modify the community" do
      let(:modifiable) { false }

      it "is not found" do
        get "/communities/#{community.public_id}/notifications"

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when the community is in player mode" do
      let(:community) { create(:community) }

      it "redirects to the community's settings with an alert" do
        get "/communities/#{community.public_id}/notifications"

        expect(response).to redirect_to(edit_community_path(community.public_id))
        expect(flash[:alert]).to match(/player mode is enabled/i)
      end
    end
  end

  describe "POST create" do
    def post_create(**params)
      post "/communities/#{community.public_id}/notifications",
        params: {
          notification: {
            notification_type: "player_heal",
            notification_color: "random",
            notification_title: "Healed",
            notification_description: "A player was healed"
          }.merge(params)
        }
    end

    it "creates a notification scoped to the community" do
      expect { post_create }.to change { community.notifications.count }.by(1)

      expect(response).to redirect_to(community_notifications_path(community, filter: "recent"))
    end

    context "when the viewer cannot modify the community" do
      let(:modifiable) { false }

      it "is not found and creates nothing" do
        expect { post_create }.not_to change { community.notifications.count }

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when the community is in player mode" do
      let(:community) { create(:community) }

      it "redirects to the community's settings with an alert" do
        post_create

        expect(response).to redirect_to(edit_community_path(community.public_id))
        expect(flash[:alert]).to match(/player mode is enabled/i)
      end
    end
  end

  describe "GET edit" do
    it "renders the notification" do
      get "/communities/#{community.public_id}/notifications/#{notification.public_id}/edit"

      expect(response).to have_http_status(:ok)
    end

    context "when the viewer cannot modify the community" do
      let(:modifiable) { false }

      it "is not found" do
        get "/communities/#{community.public_id}/notifications/#{notification.public_id}/edit"

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when the community is in player mode" do
      let(:community) { create(:community) }

      it "redirects to the community's settings with an alert" do
        get "/communities/#{community.public_id}/notifications/#{notification.public_id}/edit"

        expect(response).to redirect_to(edit_community_path(community.public_id))
      end
    end

    context "when the notification belongs to another community" do
      it "is not found" do
        foreign_notification = create(:community).notifications.first

        get "/communities/#{community.public_id}/notifications/#{foreign_notification.public_id}/edit"

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "PATCH update" do
    def patch_update(id: notification.public_id, **params)
      patch "/communities/#{community.public_id}/notifications/#{id}",
        params: {notification: {notification_title: "Updated title"}.merge(params)}
    end

    it "updates the community's own notification" do
      expect { patch_update }.to change { notification.reload.notification_title }.to("Updated title")

      expect(response).to have_http_status(:ok)
    end

    context "when the viewer cannot modify the community" do
      let(:modifiable) { false }

      it "is not found and leaves the notification untouched" do
        expect { patch_update }.not_to change { notification.reload.notification_title }

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when the community is in player mode" do
      let(:community) { create(:community) }

      it "redirects to the community's settings with an alert" do
        patch_update

        expect(response).to redirect_to(edit_community_path(community.public_id))
      end
    end

    context "when the notification belongs to another community" do
      it "is not found and leaves the foreign notification untouched" do
        foreign_notification = create(:community).notifications.first

        expect {
          patch_update(id: foreign_notification.public_id)
        }.not_to change { foreign_notification.reload.notification_title }

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "DELETE destroy" do
    def delete_notification(id: notification.public_id)
      delete "/communities/#{community.public_id}/notifications/#{id}"
    end

    it "removes the community's own notification" do
      expect { delete_notification }.to change { community.notifications.count }.by(-1)
    end

    context "when the viewer cannot modify the community" do
      let(:modifiable) { false }

      it "is not found and destroys nothing" do
        expect { delete_notification }.not_to change { community.notifications.count }

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when the community is in player mode" do
      let(:community) { create(:community) }

      it "redirects to the community's settings with an alert" do
        delete_notification

        expect(response).to redirect_to(edit_community_path(community.public_id))
      end
    end

    context "when the notification belongs to another community" do
      it "is not found and leaves the foreign notification in place" do
        foreign_community = create(:community)
        foreign_notification = foreign_community.notifications.first

        expect {
          delete_notification(id: foreign_notification.public_id)
        }.not_to change { foreign_community.notifications.count }

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
