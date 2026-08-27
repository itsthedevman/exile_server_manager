# frozen_string_literal: true

describe ESM::Websocket::Server do
  describe ".call" do
    context "when the request is not a websocket upgrade" do
      let(:env) { {"REQUEST_METHOD" => "GET", "PATH_INFO" => "/index.php"} }

      it "returns a valid Rack response instead of nil" do
        status, headers, body = ESM::Websocket::Server.call(env)

        expect(status).to eq(400)
        expect(headers).to include("content-type")
        expect(body).to respond_to(:each)
      end
    end
  end
end
