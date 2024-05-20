# frozen_string_literal: true

describe ESM::Command::Community::Mode, category: "command" do
  include_context "command" do
    let!(:user_args) { [:owner] }
  end

  include_examples "validate_command"

  describe "#execute" do
    context "when player mode is enabled" do
      before do
        community.update(player_mode_enabled: true)
      end

      it "disables player mode" do
        execution_args = {
          channel_type: :dm,
          arguments: {community_id: community.community_id}
        }

        execute!(**execution_args)

        response = ESM::Test.messages.first.content
        expect(response).not_to be_nil

        community.reload
        expect(community.player_mode_enabled?).to be(false)

        expect(response.description).to eq(I18n.t("commands.mode.disabled", community_name: community.name))
        expect(response.color).to eq(ESM::Color::Toast::GREEN)
      end
    end

    context "when player mode is disabled" do
      before do
        community.update(player_mode_enabled: false)
      end

      it "enables player mode" do
        execution_args = {
          channel_type: :dm,
          arguments: {community_id: community.community_id}
        }

        execute!(**execution_args)

        response = ESM::Test.messages.first.content
        expect(response).not_to be_nil
        community.reload

        expect(community.player_mode_enabled?).to be(true)

        expect(response.description).to eq(I18n.t("commands.mode.enabled", community_name: community.name))
        expect(response.color).to eq(ESM::Color::Toast::GREEN)
      end

      context "when there are servers" do
        before do
          # Create a server so there is one
          ESM::Test.server(for: community)
        end

        it "raises an exception" do
          execution_args = {
            channel_type: :dm,
            arguments: {community_id: community.community_id}
          }

          expect { execute!(**execution_args) }.to raise_error do |error|
            embed = error.data
            expect(embed.description).to match(/in order to enable player mode you must remove any servers you've registered via my/i)
          end
        end
      end
    end

    context "when the user is not the owner" do
      it "raises an exception" do
        non_owner = ESM::Test.user

        execution_args = {
          user: non_owner,
          channel_type: :dm,
          arguments: {community_id: community.community_id}
        }

        expect { execute!(**execution_args) }.to raise_error do |error|
          embed = error.data
          expect(embed.description).to match(/only the owner of this community has access to this command/i)
        end
      end
    end
  end
end
