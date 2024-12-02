# frozen_string_literal: true

describe ESM::Event::SendXm8Notification, :requires_connection, v2: true do
  include_context "connection"

  let!(:second_user) { ESM::Test.user }
  let!(:territory_owner) { user.steam_uid }
  let!(:territory_moderators) { [second_user.steam_uid] }

  let(:recipient_uids) { [user.steam_uid, second_user.steam_uid] }

  let(:notification_type) { "base-raid" }
  let(:xm8_sqf_function) { "ExileServer_system_xm8_sendBaseRaid" }
  let(:notification_state_details) { ESM::Xm8Notification::DETAILS_DM }
  let(:notification_content) do
    {
      territory_id: territory.encoded_id,
      territory_name: territory.name
    }.stringify_keys
  end

  let(:notification_sqf) do
    <<~SQF
      private _territory = #{territory.id} call ESMs_system_territory_get;
      _territory call #{xm8_sqf_function}
    SQF
  end

  subject(:trigger_notification) { execute_sqf!(notification_sqf) }

  before do
    second_user.exile_account
    territory.create_flag
  end

  shared_examples "sends" do
    it "is expected to send the notification and update the server's database" do
      trigger_notification

      # Check outbound messages
      wait_for { ESM::Test.messages.size }.to eq(recipient_uids.size)

      # Check database update
      notifications = ESM::ExileXm8Notification.where(state: ESM::Xm8Notification::STATE_SENT)
      wait_for { notifications.size }.to eq(recipient_uids.size)

      notifications.each do |notification|
        expect(notification.recipient_uid).to be_in(recipient_uids)

        # These don't have a territory ID
        if !["custom", "marxet-item-sold"].include?(notification_type)
          expect(notification.territory_id).to eq(territory.id)
        end

        expect(notification.type).to eq(notification_type)
        expect(notification.content).to match(notification_content)
        expect(notification.state_details).to eq(notification_state_details)
        expect(notification.acknowledged_at).not_to be(nil)
      end
    end
  end

  context "when the notification type is base-raid" do
    let(:notification_type) { "base-raid" }
    let(:xm8_sqf_function) { "ExileServer_system_xm8_sendBaseRaid" }

    include_examples "sends"
  end

  context "when the notification type is charge-plant-started" do
    let(:notification_type) { "charge-plant-started" }
    let(:xm8_sqf_function) { "ExileServer_system_xm8_sendChargePlantStarted" }

    include_examples "sends"
  end

  context "when the notification type is flag-restored" do
    let(:notification_type) { "flag-restored" }
    let(:xm8_sqf_function) { "ExileServer_system_xm8_sendFlagRestored" }

    include_examples "sends"
  end

  context "when the notification type is flag-steal-started" do
    let(:notification_type) { "flag-steal-started" }
    let(:xm8_sqf_function) { "ExileServer_system_xm8_sendFlagStealStarted" }

    include_examples "sends"
  end

  context "when the notification type is flag-stolen" do
    let(:notification_type) { "flag-stolen" }
    let(:xm8_sqf_function) { "ExileServer_system_xm8_sendFlagStolen" }

    include_examples "sends"
  end

  context "when the notification type is grind-started" do
    let(:notification_type) { "grind-started" }
    let(:xm8_sqf_function) { "ExileServer_system_xm8_sendGrindingStarted" }

    include_examples "sends"
  end

  context "when the notification type is hack-started" do
    let(:notification_type) { "hack-started" }
    let(:xm8_sqf_function) { "ExileServer_system_xm8_sendHackingStarted" }

    include_examples "sends"
  end

  context "when the notification type is protection-money-due" do
    let(:notification_type) { "protection-money-due" }
    let(:notification_sqf) { "call ExileServer_system_xm8_sendProtectionMoneyDue" }

    before do
      territory.update!(last_paid_at: 20.days.ago, xm8_protectionmoney_notified: false)
    end

    include_examples "sends"
  end

  context "when the notification type is protection-money-paid" do
    let(:notification_type) { "protection-money-paid" }
    let(:xm8_sqf_function) { "ExileServer_system_xm8_sendProtectionMoneyPaid" }

    include_examples "sends"
  end

  context "when the notification type is custom" do
    let(:notification_type) { "custom" }
    let(:notification_content) do
      hash = embed_data.to_h
      hash["fields"] = be_a(String)
      hash
    end

    let(:embed_data) do
      ESM::Arma::HashMap.new(
        title: "This is a title",
        description: "This is a description",
        fields: [
          {name: "field title", value: "field value", inline: true}
        ]
      )
    end

    let(:notification_sqf) do
      <<~SQF
        [#{recipient_uids.to_json}, #{embed_data.to_json}] call ExileServer_system_xm8_sendCustom
      SQF
    end

    include_examples "sends"

    context "when the embed data is valid" do
      it "includes title, description, fields, etc." do
        trigger_notification

        # For timing to ensure everything completes
        notifications = ESM::ExileXm8Notification.where(state: "sent")
        wait_for { notifications.size }.to eq(recipient_uids.size)

        embed = ESM::Test.messages.first.content
        expect(embed.title).to eq(embed_data[:title])
        expect(embed.description).to eq(embed_data[:description])
        embed.fields.zip(embed_data[:fields]).each do |embed_field, input_field|
          expect(embed_field.name).to eq(input_field[:name])
          expect(embed_field.value).to eq(input_field[:value])
          expect(embed_field.inline).to eq(input_field[:inline])
        end
      end
    end

    context "when the embed data is not valid" do
      let(:embed_data) { [] }

      it "logs a message to the server and discord" do
        trigger_notification

        wait_for { ESM::Test.messages.size }.to eq(1)
        message = ESM::Test.messages.first.content
        expect(message).to match("has encountered an error")
      end
    end
  end

  context "when the notification type is marxet-item-sold" do
    let(:recipient_uids) { [user.steam_uid] }
    let(:notification_type) { "marxet-item-sold" }
    let(:notification_content) { {item_name:, poptabs_received:}.stringify_keys }

    let(:item_name) { ESM::Arma::ClassLookup.all.values.sample.display_name }
    let(:poptabs_received) { Faker::Number.positive.to_i.to_s }

    let(:notification_sqf) do
      <<~SQF
        [#{recipient_uids.first.to_json}, #{item_name.to_json}, #{poptabs_received.to_json}] call ExileServer_system_xm8_sendItemSold
      SQF
    end

    include_examples "sends"
  end

  context "when the notification type is invalid" do
    let(:notification_sqf) do
      <<~SQF
        ["some-invalid-type", #{recipient_uids.to_json}, []] call ExileServer_system_xm8_send;
      SQF
    end

    it "logs a message to the server and discord" do
      trigger_notification

      wait_for { ESM::Test.messages.size }.to eq(1)
      message = ESM::Test.messages.first.content
      expect(message).to match("has encountered an error")
    end
  end

  context "when the notification has unregistered users" do
    before do
      recipient_uids # Cache before they're removed
      user.update!(steam_uid: nil)
      second_user.update!(steam_uid: nil)
    end

    it "updates the database with a failure for no registration" do
      trigger_notification

      notifications = ESM::ExileXm8Notification.where(state: ESM::Xm8Notification::STATE_FAILED)
      wait_for { notifications.size }.to eq(recipient_uids.size)

      # Nothing is sent
      expect(ESM::Test.messages.size).to eq(0)

      notifications.each do |notification|
        expect(notification.state_details).to eq(ESM::Xm8Notification::DETAILS_NOT_REGISTERED)
        expect(notification.acknowledged_at).not_to be(nil)
      end
    end
  end

  context "when the notification fails to send to direct message" do
    before do
      # Failures are when the message fails to send
      allow(ESM.bot).to receive(:deliver).and_return(nil)
    end

    it "updates the database with a failure to send" do
      trigger_notification

      notifications = ESM::ExileXm8Notification.where(state: ESM::Xm8Notification::STATE_FAILED)
      wait_for { notifications.size }.to eq(recipient_uids.size)

      # Nothing is sent
      expect(ESM::Test.messages.size).to eq(0)

      notifications.each do |notification|
        expect(notification.state_details).to eq(ESM::Xm8Notification::DETAILS_DM)
        expect(notification.acknowledged_at).not_to be(nil)
      end
    end
  end

  context "when the recipients have direct messages disallowed and they have no custom routes" do
    let!(:territory_moderators) { [] }
    let!(:recipient_uids) { [user.steam_uid] }

    before do
      create(:user_notification_preference, user:, server:, base_raid: false)
    end

    it "updates the database with a failure because of no destinations" do
      trigger_notification

      notifications = ESM::ExileXm8Notification.where(state: ESM::Xm8Notification::STATE_FAILED)
      wait_for { notifications.size }.to eq(recipient_uids.size)

      expect(ESM::Test.messages.size).to eq(0)

      notifications.each do |notification|
        expect(notification.state_details).to eq(ESM::Xm8Notification::DETAILS_NO_DESTINATION)
      end
    end
  end

  context "when the recipients have custom routes" do
    let(:channel_id) { ESM::Test.channel(in: community).id }
    let(:destination_community) { community }

    before do
      # Disable DM notifications to allow for easier testing
      create(:user_notification_preference, user:, server:, base_raid: false)
      create(:user_notification_preference, user: second_user, server:, base_raid: false)
    end

    context "when the custom route is disabled" do
      let!(:territory_moderators) { [] }
      let!(:recipient_uids) { [user.steam_uid] }

      let!(:routes) do
        [
          create(
            :user_notification_route,
            user:,
            destination_community:,
            channel_id:,
            enabled: false
          )
        ]
      end

      it "does not send" do
        trigger_notification

        notifications = ESM::ExileXm8Notification.where(state: ESM::Xm8Notification::STATE_FAILED)
        wait_for { notifications.size }.to eq(recipient_uids.size)

        expect(ESM::Test.messages.size).to eq(0)
      end
    end

    context "when the custom route is not accepted yet" do
      let!(:routes) do
        [
          create(
            :user_notification_route,
            user:,
            destination_community:,
            channel_id:,
            user_accepted: false
          ),

          create(
            :user_notification_route,
            user: second_user,
            destination_community:,
            channel_id:,
            community_accepted: false
          )
        ]
      end

      it "does not send" do
        trigger_notification

        notifications = ESM::ExileXm8Notification.where(state: ESM::Xm8Notification::STATE_FAILED)
        wait_for { notifications.size }.to eq(recipient_uids.size)

        expect(ESM::Test.messages.size).to eq(0)
      end
    end

    context "when the custom route sends to any server and they are separate channels" do
      let!(:routes) do
        [
          create(
            :user_notification_route,
            user:,
            destination_community:,
            channel_id:
          ),

          create(
            :user_notification_route,
            user: second_user,
            destination_community:,
            channel_id: ESM::Test.channel(in: destination_community).id
          )
        ]
      end

      it "sends to the channel" do
        trigger_notification

        notifications = ESM::ExileXm8Notification.where(state: ESM::Xm8Notification::STATE_SENT)
        wait_for { notifications.size }.to eq(recipient_uids.size)

        expect(ESM::Test.messages.size).to eq(2)

        channel_ids = ESM::Test.messages.destinations.map { |c| c.id.to_s }
        expect(channel_ids).to match(routes.map(&:channel_id))
      end
    end

    context "when the custom route sends to a specific server" do
      let!(:territory_moderators) { [] }
      let!(:recipient_uids) { [user.steam_uid] }

      let!(:routes) do
        [
          create(
            :user_notification_route,
            user:,
            destination_community:,
            channel_id:,
            source_server_id: server.id
          ),

          create(
            :user_notification_route,
            user: second_user,
            destination_community:,
            channel_id:,
            source_server_id: ESM::Test.server(for: community).id
          )
        ]
      end

      it "sends to channels that match the one source server" do
        trigger_notification

        notifications = ESM::ExileXm8Notification.where(state: ESM::Xm8Notification::STATE_SENT)
        wait_for { notifications.size }.to eq(recipient_uids.size)

        expect(ESM::Test.messages.size).to eq(1)

        channel = ESM::Test.messages.first.destination
        expect(channel.id.to_s).to eq(routes.first.channel_id)
      end
    end

    context "when the custom route sends to any server and they are the same channels" do
      let!(:routes) do
        [
          create(
            :user_notification_route,
            user:,
            destination_community:,
            channel_id:
          ),

          create(
            :user_notification_route,
            user: second_user,
            destination_community:,
            channel_id:
          )
        ]
      end

      it "sends to channels that match the one source server" do
        trigger_notification

        notifications = ESM::ExileXm8Notification.where(state: ESM::Xm8Notification::STATE_SENT)
        wait_for { notifications.size }.to eq(recipient_uids.size)

        expect(ESM::Test.messages.size).to eq(1)

        channel = ESM::Test.messages.first.destination
        routes.each do |route|
          expect(route.channel_id).to eq(channel.id.to_s)
        end
      end
    end
  end
end
