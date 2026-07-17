# frozen_string_literal: true

require "rails_helper"

# The Discord-embed landing pages: GET /requests/:uuid/accept|decline. These links live in
# Discord DMs and render full success/not-found pages. The bot round-trip is stubbed at the
# ESM::Service::API boundary. Regression guard: accept/decline return the handler's result
# (falsy on a successful decline), NOT a success flag, so the controller must render success
# whenever the call doesn't raise - the old `if request.decline` branch showed "failed" on a
# successful decline.
RSpec.describe "Requests", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  def request_for(requestee, requestor: create(:user), command_name: "add",
    arguments: {"territory_id" => "ALPHA"})
    ESM::Request.create!(
      requestor_user_id: requestor.id,
      requestee_user_id: requestee.id,
      requested_from_channel_id: nil,
      command_name:,
      command_arguments: arguments
    )
  end

  describe "GET accept" do
    before { allow(ESM::Service::API).to receive(:call).and_return(nil) }

    it "accepts the caller's request and renders success" do
      request = request_for(user)

      get "/requests/#{request.uuid}/accept"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Request Accepted!")
      expect(ESM::Service::API).to have_received(:call).with(:requests_accept, id: request.id)
    end

    it "renders not-found for a request that isn't the caller's" do
      request = request_for(create(:user))

      get "/requests/#{request.uuid}/accept"

      expect(ESM::Service::API).not_to have_received(:call)
      expect(response.body).to include("Request Not Found")
    end
  end

  describe "GET decline" do
    # nil is what a real successful decline returns; the success page must still render.
    before { allow(ESM::Service::API).to receive(:call).and_return(nil) }

    it "declines the caller's request and renders success despite the falsy return" do
      request = request_for(user)

      get "/requests/#{request.uuid}/decline"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Request Declined!")
      expect(ESM::Service::API).to have_received(:call).with(:requests_decline, id: request.id)
    end
  end
end
