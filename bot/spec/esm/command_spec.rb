# frozen_string_literal: true

describe ESM::Command do
  subject(:commands) { described_class }

  context "when ESM has commands" do
    it do
      expect(commands.all).not_to be_empty
    end

    it "is organized by type" do
      expect(commands.by_type[:player]).not_to be_empty
      expect(commands.by_type[:admin]).not_to be_empty
    end

    it "organized by namespace" do
      base_class = ESM::Command
      territory_commands = base_class::Territory
      server_commands = base_class::Server
      request_commands = base_class::Request
      pictures_commands = base_class::Pictures
      general_commands = base_class::General
      my_commands = base_class::My
      community_commands = base_class::Community

      expect(commands.by_namespace).to match(
        a_hash_including(
          territory: {
            upgrade: territory_commands::Upgrade,
            set_id: territory_commands::SetId,
            admin: {
              list: territory_commands::ServerTerritories,
              restore: territory_commands::Restore
            },
            remove_player: territory_commands::Remove,
            promote_player: territory_commands::Promote,
            pay: territory_commands::Pay,
            demote_player: territory_commands::Demote,
            add_player: territory_commands::Add
          },
          server: {
            uptime: server_commands::Uptime,
            my: {
              territories: server_commands::Territories,
              player: server_commands::Me
            },
            stuck: server_commands::Stuck,
            admin: {
              execute_code: server_commands::Sqf,
              reset_player: server_commands::Reset,
              modify_player: server_commands::Player,
              search_logs: server_commands::Logs,
              find: server_commands::Info,
              broadcast: server_commands::Broadcast
            },
            details: server_commands::Server,
            reward: server_commands::Reward,
            gamble: server_commands::Gamble
          },
          request: {
            decline: request_commands::Decline,
            accept: request_commands::Accept
          },
          pictures: {
            snek: pictures_commands::Snek,
            meow: pictures_commands::Meow,
            doggo: pictures_commands::Doggo,
            birb: pictures_commands::Birb
          },
          my: {
            steam_uid: my_commands::SteamUid,
            requests: my_commands::Requests,
            preferences: my_commands::Preferences,
            aliases: my_commands::Aliases
          },
          register: general_commands::Register,
          help: general_commands::Help,
          community: {
            admin: {
              find_player: community_commands::Whois,
              reset_cooldown: community_commands::ResetCooldown,
              change_mode: community_commands::Mode
            },
            servers: community_commands::Servers,
            id: community_commands::Id
          }
        )
      )
    end
  end

  describe ".[]" do
    context "when the input is a 'OG command name'" do
      it do
        expect(commands["help"]).to be(ESM::Command::General::Help)
      end
    end

    context "when the input is a 'slash command'" do
      it do
        expect(commands["/community servers"]).to be(ESM::Command::Community::Servers)
      end
    end

    context "when the input is a 'slash command' without a slash" do
      it do
        expect(commands["server my player"]).to be(ESM::Command::Server::Me)
      end
    end

    context "when the input is the end of a 'slash command'" do
      it do
        expect(commands["promote_player"]).to be(ESM::Command::Territory::Promote)
      end
    end

    context "when the input is invalid" do
      it do
        expect(commands["this command cannot exist"]).to be(nil)
      end
    end
  end

  describe ".get" do
    it "is aliased correctly" do
      expect(commands.get("birb")).to be(ESM::Command::Pictures::Birb)
    end
  end

  describe ".include?" do
    context "when the command exists" do
      it do
        expect(commands.include?("help")).to be(true)
      end
    end

    context "when the command does not exist" do
      it do
        expect(commands.include?("This command cannot exist")).to be(false)
      end
    end
  end
end
