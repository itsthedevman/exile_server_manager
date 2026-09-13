# frozen_string_literal: true

require "rake"

RSpec.describe "cooldowns:backfill_reward_scope_keys" do
  let!(:community) { create(:community) }
  let!(:server) { create(:server, community:, server_version: "2.0.4") }
  let!(:user) { create(:user) }

  before(:context) do
    Rake.application.rake_require("cooldowns", [ESM.root.join("tasks").to_s])
  end

  # Examples that don't assert the summary would otherwise print it into the spec output
  before { allow($stdout).to receive(:puts) }

  # #execute skips the :environment prerequisite, which the spec boot has already done
  def run_task
    Rake::Task["cooldowns:backfill_reward_scope_keys"].execute
  end

  def reward_cooldown(scope_key: nil, command_name: "reward", steam_uid: user.steam_uid)
    create(:cooldown, command_name:, scope_key:, steam_uid:, community_id: community.id, server_id: server.id)
  end

  it "moves a v2 server's unscoped reward cooldown onto the default package" do
    cooldown = reward_cooldown

    expect { run_task }.to output(/Moved 1 .+\nDeleted 0 /).to_stdout
    expect(cooldown.reload.scope_key).to eq("default")
  end

  # Reward::V1 checks the command's own unscoped cooldown, so moving these would lose every one of them
  it "leaves a v1 server's rows where Reward::V1 reads them" do
    server.update_column(:server_version, "1.9.9")
    cooldown = reward_cooldown

    expect { run_task }.to output(/Moved 0 .+\nDeleted 0 /).to_stdout
    expect(cooldown.reload.scope_key).to be_nil
  end

  it "leaves a server that has never connected alone, since it reads as v1" do
    server.update_column(:server_version, nil)
    cooldown = reward_cooldown

    run_task

    expect(cooldown.reload.scope_key).to be_nil
  end

  it "leaves other commands and rows that already have a package alone" do
    gamble = reward_cooldown(command_name: "gamble")
    vip = reward_cooldown(scope_key: "vip")

    run_task

    expect(gamble.reload.scope_key).to be_nil
    expect(vip.reload.scope_key).to eq("vip")
  end

  # The new code wrote a default-package row before this ran. That one is live, and the unique index allows one.
  it "deletes an old row a newer default-package cooldown already replaced" do
    old = reward_cooldown
    live = reward_cooldown(scope_key: "default")

    expect { run_task }.to output(/Moved 0 .+\nDeleted 1 /).to_stdout
    expect(ESM::Cooldown.exists?(old.id)).to be(false)
    expect(live.reload.scope_key).to eq("default")
  end

  it "only counts a replacement belonging to the same player" do
    cooldown = reward_cooldown
    reward_cooldown(scope_key: "default", steam_uid: create(:user).steam_uid)

    expect { run_task }.to output(/Moved 1 .+\nDeleted 0 /).to_stdout
    expect(cooldown.reload.scope_key).to eq("default")
  end

  it "changes nothing when run a second time" do
    reward_cooldown

    run_task

    expect { run_task }.to output(/Moved 0 .+\nDeleted 0 /).to_stdout
  end
end
