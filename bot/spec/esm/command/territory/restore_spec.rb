# frozen_string_literal: true

describe ESM::Command::Territory::Restore, category: "command" do
  include_context "command"
  include_examples "validate_command"

  describe "V1" do
    describe "#execute" do
      include_context "connection_v1"

      let(:territory_id) { Faker::Alphanumeric.alphanumeric(number: 3..30) }

      before do
        grant_command_access!(community, "restore")
      end

      context "when the territory has been soft deleted due to missing payment" do
        it "restores the territory" do
          wsc.flags.SUCCESS = true

          request = execute!(arguments: {server_id: server.server_id, territory_id: territory_id})
          expect(request).not_to be_nil
          wait_for { connection.requests }.to be_blank
          wait_for { ESM::Test.messages.size }.to eq(1)

          embed = ESM::Test.messages.first.content
          expect(embed.description).to eq("Hey #{user.mention}, `#{territory_id}` has been restored")
        end
      end

      context "when the territory has been hard deleted from the database" do
        it "fails to restore the territory and returns a message" do
          wsc.flags.SUCCESS = false

          request = execute!(arguments: {server_id: server.server_id, territory_id: territory_id})
          expect(request).not_to be_nil
          wait_for { connection.requests }.to be_blank
          wait_for { ESM::Test.messages.size }.to eq(1)

          embed = ESM::Test.messages.first.content
          expect(embed.description).to eq("I'm sorry #{user.mention}, `#{territory_id}` no longer exists on `#{server.server_id}`.")
        end
      end
    end
  end

  describe "V2", category: "command" do
    it "is an admin command" do
      expect(command.type).to eq(:admin)
    end

    describe "#on_execute", requires_connection: true do
      include_context "connection"

      before do
        grant_command_access!(community, "restore")
      end

      subject(:execute_command) do
        execute!(
          arguments: {
            server_id: server.server_id,
            territory_id: territory.encoded_id
          }
        )
      end

      ##########################################################################

      context "when the territory has deleted_at set but hasn't been deleted yet" do
        let!(:container) do
          create(
            :exile_container,
            territory_id: territory.id,
            account_uid: user.exile_account.uid,
            deleted_at: Time.current
          )
        end

        let!(:construction) do
          create(
            :exile_construction,
            territory_id: territory.id,
            account_uid: user.exile_account.uid,
            deleted_at: Time.current
          )
        end

        before do
          territory.update!(
            deleted_at: Time.current,
            xm8_protectionmoney_notified: true,
            last_paid_at: 7.days.ago
          )
        end

        it "restores the territory" do
          expect(territory.deleted_at).not_to be(nil)
          expect(container.deleted_at).not_to be(nil)
          expect(construction.deleted_at).not_to be(nil)

          previous_last_paid_at = territory.last_paid_at

          expect { execute_command }.not_to raise_error

          territory.reload
          expect(territory.deleted_at).to be(nil)
          expect(territory.xm8_protectionmoney_notified).to be(false)
          expect(territory.last_paid_at).not_to eq(previous_last_paid_at)

          container.reload
          expect(container.deleted_at).to be(nil)

          construction.reload
          expect(construction.deleted_at).to be(nil)
        end
      end

      context "when the territory no longer exists in the database" do
        before do
          territory.delete
        end

        include_examples "error_territory_id_does_not_exist"
      end
    end
  end
end
