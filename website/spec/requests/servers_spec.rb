# frozen_string_literal: true

RSpec.describe "Servers", type: :request do
  let(:community) { create(:community) }
  let(:server) { create(:server, community:) }
  let(:user) { create(:user) }

  # Whether the viewer can manage the server decides how much the page explains, so it's stated per example rather than
  # left to whatever the bot would say about this user's Discord roles.
  let(:manageable) { false }

  before do
    sign_in user
    allow_any_instance_of(ESM::Server).to receive(:connected?).and_return(false)
    allow_any_instance_of(ESM::Community).to receive(:modifiable_by?).and_return(manageable)
  end

  describe "GET live" do
    let(:info) do
      ESM::Steam::ServerQuery::Info.new(
        protocol: 17, name: "exilemod.com", map: "tanoa", folder: "Arma3", game: "exile",
        app_id: 0, players: 12, max_players: 100, bots: 0, version: "2.20.152984"
      )
    end

    it "renders what the server reported" do
      allow(ESM::Steam::ServerQuery).to receive(:info).and_return(info)

      get "/servers/#{server.public_id}/live"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("tanoa", "12/100")
    end

    # The Arma build only matters when someone can't connect, which is rare enough that it doesn't earn a permanent
    # line in a rail that renders on every page of the hub.
    it "leaves the game version out" do
      allow(ESM::Steam::ServerQuery).to receive(:info).and_return(info)

      get "/servers/#{server.public_id}/live"

      expect(response.body).not_to include("2.20.152984")
    end

    it "asks the query port, which is one past the port players connect on" do
      allow(ESM::Steam::ServerQuery).to receive(:info).and_return(info)

      get "/servers/#{server.public_id}/live"

      expect(ESM::Steam::ServerQuery).to have_received(:info)
        .with(host: server.server_ip, port: server.server_port.to_i + 1)
    end

    context "when the server can't be reached" do
      before do
        allow(ESM::Steam::ServerQuery).to receive(:info)
          .and_raise(ESM::Steam::ServerQuery::Timeout, "did not answer")
      end

      # The whole reason this is its own lazy request. A server that's down, firewalled, or simply not answering must
      # cost this frame and nothing else.
      it "renders an empty frame rather than failing" do
        get "/servers/#{server.public_id}/live"

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("Players")
      end

      # A player can't fix an address they don't own, so the panel just stays empty for them.
      it "says nothing to a player, even on a server that is up" do
        allow_any_instance_of(ESM::Server).to receive(:connected?).and_return(true)

        get "/servers/#{server.public_id}/live"

        expect(response.body).not_to include("No answer")
      end

      context "and the viewer manages the server" do
        let(:manageable) { true }

        # A server ESM is already talking to that still won't answer a query has usually been given the wrong address
        # here, so the message names what was dialed rather than restating that something failed.
        it "names the address it dialed when the server is up and still silent" do
          allow_any_instance_of(ESM::Server).to receive(:connected?).and_return(true)

          get "/servers/#{server.public_id}/live"

          expect(response.body).to include("<code class=\"text-warning-emphasis\">#{server.server_ip}:#{server.query_port}</code>")
        end

        # The ip is free text on the server form, so it can't be trusted into a template.
        it "escapes an address rather than rendering it as markup" do
          allow_any_instance_of(ESM::Server).to receive(:connected?).and_return(true)
          server.update!(server_ip: "<script>alert(1)</script>")

          get "/servers/#{server.public_id}/live"

          expect(response.body).to include("&lt;script&gt;")
          expect(response.body).not_to include("<script>alert(1)</script>")
        end

        # The status line directly above already says Offline. Repeating it under a heading the owner can't act on is
        # noise, not an explanation.
        it "stays quiet when the server is simply down" do
          get "/servers/#{server.public_id}/live"

          expect(response.body).not_to include("No answer")
        end
      end
    end

    it "does not leak an unexpected reply as a 500" do
      allow(ESM::Steam::ServerQuery).to receive(:info)
        .and_raise(ESM::Steam::ServerQuery::UnexpectedResponse, "reply was split")

      get "/servers/#{server.public_id}/live"

      expect(response).to have_http_status(:ok)
    end

    it "404s for a server that doesn't exist" do
      get "/servers/#{SecureRandom.uuid}/live"

      expect(response).to have_http_status(:not_found)
    end

    it "requires a signed-in user" do
      sign_out user

      get "/servers/#{server.public_id}/live"

      expect(response).to redirect_to("/login")
    end
  end
end
