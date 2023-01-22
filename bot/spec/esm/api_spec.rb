# frozen_string_literal: true

require "rack/test"

describe ESM::API do
  include Rack::Test::Methods

  let!(:app) { described_class }
  let(:channel) { ESM::Test.channel }

  describe "GET /channel/:id" do
    it "finds the channel" do
      # TODO: Once v2 code is merged.
    end

    it "fails to find the channel" do
      get "/channel/nope"
      expect(last_response).not_to be_ok
    end

    # TODO: Once v2 code is merged.
    it "fails to find the community"
    it "fails to find the user"
    it "fails to find the channel due to the community filter"
    it "fails to find the channel due to the user filter"
  end
end
