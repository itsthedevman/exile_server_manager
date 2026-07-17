# frozen_string_literal: true

# The player-facing requests inbox (/account/requests): pending requests addressed to
# you, with turbo accept/decline. The accept/decline round-trip to the bot is stubbed
# at the ESM::Service::API boundary; the model's own accept!/reject! flow is covered
# in the service suite.
RSpec.describe "Users::Requests", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  def request_for(requestee, requestor: create(:user), command_name: "add", status: :pending,
    arguments: {"territory_id" => "ALPHA", "server_id" => "svr"})
    ESM::Request.create!(
      requestor_user_id: requestor.id,
      requestee_user_id: requestee.id,
      requested_from_channel_id: nil,
      command_name:,
      command_arguments: arguments,
      status:
    )
  end

  describe "GET index" do
    it "lists the caller's pending requests" do
      requestor = create(:user, discord_username: "RequestorGuy")
      request_for(user, requestor:, arguments: {"territory_id" => "ALPHA", "server_id" => "svr"})

      get "/account/requests"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("RequestorGuy wants to add you to a territory")
      expect(response.body).to include("ALPHA")
    end

    it "shows the empty state when nothing is pending for the caller" do
      request_for(user, status: :accepted)  # already answered
      request_for(create(:user))            # addressed to someone else

      get "/account/requests"

      expect(response.body).to include("no pending requests")
    end
  end

  describe "POST accept" do
    # A successful decline returns the bot handler's result (nil), not a success flag; the
    # controller must treat "didn't raise" as success rather than branching on this value.
    before { allow(ESM::Service::API).to receive(:call).and_return(nil) }

    it "responds to the caller's pending request and removes the row" do
      request = request_for(user)

      post "/account/requests/#{request.uuid}/accept", as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(ESM::Service::API).to have_received(:call).with(:requests_accept, id: request.id)
      expect(response.body).to include("Request accepted")
    end

    it "does not act on another user's request" do
      request = request_for(create(:user))

      post "/account/requests/#{request.uuid}/accept", as: :turbo_stream

      expect(ESM::Service::API).not_to have_received(:call)
      expect(response.body).to include("no longer available")
    end

    it "does not act on an already-answered request" do
      request = request_for(user, status: :accepted)

      post "/account/requests/#{request.uuid}/accept", as: :turbo_stream

      expect(ESM::Service::API).not_to have_received(:call)
    end
  end

  describe "POST decline" do
    # A successful decline returns the bot handler's result (nil), not a success flag; the
    # controller must treat "didn't raise" as success rather than branching on this value.
    before { allow(ESM::Service::API).to receive(:call).and_return(nil) }

    it "declines the caller's pending request" do
      request = request_for(user)

      post "/account/requests/#{request.uuid}/decline", as: :turbo_stream

      expect(ESM::Service::API).to have_received(:call).with(:requests_decline, id: request.id)
      expect(response.body).to include("Request declined")
    end
  end

  it "requires a signed-in user" do
    sign_out user

    get "/account/requests"

    expect(response).to redirect_to("/login")
  end
end
