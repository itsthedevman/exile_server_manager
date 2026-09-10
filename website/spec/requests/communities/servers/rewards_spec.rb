# frozen_string_literal: true

RSpec.describe "Communities::Servers::Rewards", type: :request do
  let(:community) { create(:community) }
  let(:server) { create(:server, community:, ui_version: "2.1.0") }
  let(:user) { create(:user) }

  let(:default_package) { server.server_rewards.default.first }

  before do
    sign_in user
    allow_any_instance_of(ESM::Community).to receive(:modifiable_by?).and_return(true)

    # The nav gates its entries on whether a command is reachable, which is a question only the bot can answer
    allow(ESM::CommandAccess).to receive(:new).and_return(
      instance_double(ESM::CommandAccess, verdict: ESM::Command::Permission::ALLOWED)
    )
  end

  # The editor is not enforced locally, the same as every other version gate on this site. A spec about what an older
  # server may do has to leave that bypass behind first.
  def enforce_versions!
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
  end

  def base_path
    "/communities/#{community.public_id}/servers/#{server.public_id}/rewards"
  end

  def create_package(reward_id, **attributes)
    server.server_rewards.create!(reward_id:, **attributes)
  end

  def package_params(**overrides)
    {
      reward_package: {
        name: "Welcome package",
        reward_id: "welcome",
        enabled: "1",
        player_poptabs: "5000",
        locker_poptabs: "0",
        respect: "0",
        custom_cooldown: "0",
        cooldown_quantity: "",
        cooldown_type: ""
      }.merge(overrides)
    }
  end

  describe "GET /rewards/new" do
    it "opens an editor for a new package" do
      get "#{base_path}/new"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("New reward package")
      expect(response.body).to include("reward_package[reward_items][][classname]")
    end

    # Packages are a v2 UI feature. A v1 server is told what to hand out when it connects, and that only ever
    # describes the one default package.
    it "is not there at all for a server still on the v1 UI" do
      server.update!(ui_version: "1.0.0")

      get "#{base_path}/new"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /rewards/:reward_id/edit" do
    it "opens the package with what it holds" do
      create_package("welcome", name: "Welcome", player_poptabs: 5_000, reward_items: {Exile_Item_EMRE: 2})

      get "#{base_path}/welcome/edit"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Exile_Item_EMRE")
      expect(response.body).to include("5000")
    end

    # It is what the command falls back to when nobody names a package, by that exact name
    it "will not let the default package be renamed to something else" do
      get "#{base_path}/default/edit"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("without naming a package")
    end

    it "asks where each vehicle should go" do
      get "#{base_path}/default/edit"

      expect(response.body).to include("reward_package[reward_vehicles][][class_name]")
      expect(response.body).to include("Let the player decide")
    end

    # spawnReward is SQF that shipped with 2.1.0. An owner on 2.0.x can still build the rest of a package.
    it "offers no vehicles on a server too old to spawn one, and says why" do
      enforce_versions!
      server.update!(server_version: "2.0.4")

      get "#{base_path}/default/edit"

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("reward_package[reward_vehicles][][class_name]")
      expect(response.body).to include("Handing a vehicle over needs 2.1.0 or newer")
    end

    it "404s on a code that is not there" do
      get "#{base_path}/nothing/edit"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /rewards" do
    it "creates the package" do
      expect { post base_path, params: package_params, as: :turbo_stream }
        .to change(server.server_rewards, :count).by(1)

      package = server.server_rewards.find_by(reward_id: "welcome")

      expect(package.name).to eq("Welcome package")
      expect(package.player_poptabs).to eq(5_000)
      expect(package.enabled).to be(true)
    end

    it "sums the rows that named the same item twice" do
      post base_path,
        params: package_params(
          reward_items: [
            {classname: "Exile_Item_EMRE", quantity: "2"},
            {classname: "Exile_Item_EMRE", quantity: "3"},
            {classname: "", quantity: "9"}
          ]
        ),
        as: :turbo_stream

      expect(server.server_rewards.find_by(reward_id: "welcome").reward_items).to eq({Exile_Item_EMRE: 5})
    end

    it "keeps the vehicle's destination and drops anything else the form sent" do
      post base_path,
        params: package_params(
          reward_vehicles: [{class_name: "Exile_Car_Hunter", spawn_location: "virtual_garage"}]
        ),
        as: :turbo_stream

      expect(server.server_rewards.find_by(reward_id: "welcome").reward_vehicles).to eq(
        [{class_name: "Exile_Car_Hunter", spawn_location: "virtual_garage"}]
      )
    end

    # The code is typed by a player and routed on by the site, so it is held to what survives both
    it "refuses a code that is not a code" do
      expect { post base_path, params: package_params(reward_id: "Welcome Package!"), as: :turbo_stream }
        .not_to change(server.server_rewards, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("lowercase letters, numbers, underscores and dashes")
    end

    it "refuses a code another package on this server already answers to" do
      create_package("welcome")

      expect { post base_path, params: package_params, as: :turbo_stream }
        .not_to change(server.server_rewards, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("already used by another package")
    end

    it "refuses a cooldown with no unit" do
      post base_path,
        params: package_params(custom_cooldown: "1", cooldown_quantity: "2"),
        as: :turbo_stream

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("have to be set together")
    end

    # The switch is the whole question, so a number left behind in the fields it hides is not an answer
    it "falls back to the command's cooldown when the switch is off" do
      post base_path,
        params: package_params(cooldown_quantity: "2", cooldown_type: "days"),
        as: :turbo_stream

      expect(server.server_rewards.find_by(reward_id: "welcome").cooldown_time).to be_nil
    end
  end

  describe "PATCH /rewards/:reward_id" do
    it "updates what the package holds" do
      create_package("welcome", player_poptabs: 100)

      patch "#{base_path}/welcome",
        params: package_params(
          player_poptabs: "9000", custom_cooldown: "1", cooldown_quantity: "2", cooldown_type: "days"
        ),
        as: :turbo_stream

      package = server.server_rewards.find_by(reward_id: "welcome")

      expect(package.player_poptabs).to eq(9_000)
      expect(package.cooldown_time).to eq(2.days)
    end

    it "hands a package back to the command's cooldown when the switch is turned off" do
      create_package("welcome", cooldown_quantity: 2, cooldown_type: "days")

      patch "#{base_path}/welcome", params: package_params, as: :turbo_stream

      expect(server.server_rewards.find_by(reward_id: "welcome").cooldown_time).to be_nil
    end

    # An owner on 2.0.x never sees the vehicle fields, so their absence from the form is not them being cleared
    it "leaves a package's vehicles alone on a server that cannot spawn them" do
      enforce_versions!
      server.update!(server_version: "2.0.4")
      create_package(
        "welcome",
        reward_vehicles: [{class_name: "Exile_Car_Hunter", spawn_location: "nearby"}]
      )

      patch "#{base_path}/welcome", params: package_params(player_poptabs: "1"), as: :turbo_stream

      expect(server.server_rewards.find_by(reward_id: "welcome").reward_vehicles).to eq(
        [{class_name: "Exile_Car_Hunter", spawn_location: "nearby"}]
      )
    end

    it "ignores an attempt to rename the default package" do
      patch "#{base_path}/default", params: package_params(reward_id: "renamed"), as: :turbo_stream

      expect(server.server_rewards.find_by(reward_id: "default")).to be_present
      expect(server.server_rewards.find_by(reward_id: "renamed")).to be_nil
    end
  end

  describe "PATCH /rewards/:reward_id/toggle_enabled" do
    it "turns a package off and back on" do
      create_package("welcome", player_poptabs: 100)

      patch "#{base_path}/welcome/toggle_enabled", as: :turbo_stream
      expect(server.server_rewards.find_by(reward_id: "welcome").enabled).to be(false)

      patch "#{base_path}/welcome/toggle_enabled", as: :turbo_stream
      expect(server.server_rewards.find_by(reward_id: "welcome").enabled).to be(true)
    end

    # There is no off switch for the package itself, so this is the one thing an owner can do to it
    it "turns the default package off" do
      patch "#{base_path}/default/toggle_enabled", as: :turbo_stream

      expect(server.server_rewards.default.first.enabled).to be(false)
      expect(response.body).to include("is turned off")
    end
  end

  describe "DELETE /rewards/:reward_id" do
    it "deletes the package" do
      create_package("welcome")

      expect { delete "#{base_path}/welcome", as: :turbo_stream }
        .to change(server.server_rewards, :count).by(-1)
    end

    # The dashboard offers it outright and the command falls back to it. A server without one answers nobody.
    it "refuses to delete the default package" do
      expect { delete "#{base_path}/default", as: :turbo_stream }
        .not_to change(server.server_rewards, :count)

      expect(response.body).to include("default package cannot be deleted")
    end
  end

  describe "the server edit page" do
    # The one package a player reaches without being told anything is the one an owner has to be able to find, so it
    # gets a block of its own rather than a row that reads like every other row
    it "sets the default package apart from the ones claimed by code" do
      default_package.update!(player_poptabs: 1_000)
      create_package("welcome", name: "Welcome", player_poptabs: 5_000)

      get "/communities/#{community.public_id}/servers/#{server.public_id}/edit"

      expect(response.body).to include("without naming a package")
      expect(response.body).to include("Code packages")
    end

    # The command refuses an empty package and the dashboard leaves it off, so a row describing one would be a row
    # for something that does not work
    it "reads a default package holding nothing as one that isn't there" do
      get "/communities/#{community.public_id}/servers/#{server.public_id}/edit"

      expect(response.body).to include("No default package")
      expect(response.body).to include("without a code get nothing")
    end

    # The amounts are a hover away in the tooltip. The row is for finding the package, not reading it.
    it "names what a package holds without counting it out" do
      create_package(
        "welcome",
        reward_items: {Exile_Item_EMRE: 2},
        reward_vehicles: [{class_name: "Exile_Car_Hunter", spawn_location: "nearby"}]
      )

      get "/communities/#{community.public_id}/servers/#{server.public_id}/edit"

      expect(response.body).to include(">Item<")
      expect(response.body).to include(">Vehicle<")
      expect(response.body).not_to include(">1 item<")
    end

    it "invites a first code package when there are none" do
      get "/communities/#{community.public_id}/servers/#{server.public_id}/edit"

      expect(response.body).to include("No code packages yet")
    end

    it "lists the packages instead of the single reward form" do
      create_package("welcome", name: "Welcome", player_poptabs: 5_000)

      get "/communities/#{community.public_id}/servers/#{server.public_id}/edit"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("New package")
      expect(response.body).to include("welcome")

      # The repeater the single-package form is built around
      expect(response.body).not_to include("server[server_rewards][reward_items]")
    end

    it "keeps the single reward form for a server still on the v1 UI" do
      server.update!(ui_version: "1.0.0")

      get "/communities/#{community.public_id}/servers/#{server.public_id}/edit"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("server-rewards")
      expect(response.body).not_to include("New package")
    end
  end
end
