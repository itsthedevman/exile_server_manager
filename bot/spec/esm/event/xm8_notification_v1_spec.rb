# frozen_string_literal: true

describe ESM::Event::Xm8NotificationV1 do
  include_context "connection_v1"

  let!(:community) { ESM::Test.community }
  let!(:server) { ESM::Test.server(for: community) }
  let!(:user) { ESM::Test.user }
  let!(:second_user) { ESM::Test.user }
  let!(:recipients) { [user.steam_uid, second_user.steam_uid] }
  let(:territory) { TerritoryGenerator.generate.to_ostruct }

  def run_test(log_xm8_event: false, expected_messages: [])
    community.update(log_xm8_event: log_xm8_event)

    expect { wsc.send_xm8_notification(**attributes) }.not_to raise_error
    wait_for { ESM::Test.messages.size }.to eq(expected_messages.size)

    # To ensure all messages have been sent
    sleep(1)
    wait_for { ESM::Test.messages.size }.to eq(expected_messages.size)

    # Check the embeds
    expected_messages.each_with_index do |message, index|
      embed = ESM::Test.messages[index].second
      expect(embed.title).to eq(message[:title])
      expect(embed.description).to eq(message[:description])
    end
  end

  describe "Bad Data" do
    it "logs invalid type"
    it "logs invalid attributes"
  end

  describe "Custom routes" do
    let!(:event_service) { ESM::Event::Xm8NotificationV1.new(server: server, parameters: parameters) }
    let(:parameters) do
      OpenStruct.new(
        type: "base-raid",
        recipients: {r: recipients}.to_json,
        message: territory.territory_name,
        id: territory.esm_custom_id || territory.id
      )
    end

    it "does not send (no routes)" do
      results = nil
      expect { results = event_service.run! }.not_to raise_error

      expect(results.size).to eq(2)
      expect(results.all? { |_user, status| status[:custom_routes][:expected] == 0 }).to eq(true)
    end

    it "does not send (disabled)" do
      create(
        :user_notification_route,
        enabled: false,
        user: user,
        destination_community: community,
        channel_id: ESM::Community::ESM::SPAM_CHANNEL
      )

      results = nil
      expect { results = event_service.run! }.not_to raise_error

      expect(results.size).to eq(2)
      expect(results.all? { |_user, status| status[:custom_routes][:expected] == 0 }).to eq(true)
    end

    it "does not send (not accepted)" do
      create(
        :user_notification_route,
        user: user,
        destination_community: community,
        channel_id: ESM::Community::ESM::SPAM_CHANNEL,
        user_accepted: false
      )

      create(
        :user_notification_route,
        user: second_user,
        destination_community: community,
        channel_id: ESM::Community::ESM::SPAM_CHANNEL,
        community_accepted: false
      )

      results = nil
      expect { results = event_service.run! }.not_to raise_error

      expect(results.size).to eq(2)
      expect(results.all? { |_user, status| status[:custom_routes][:expected] == 0 }).to eq(true)
    end

    it "sends (Any server)" do
      create(
        :user_notification_route,
        user: user,
        destination_community: community,
        channel_id: ESM::Community::ESM::SPAM_CHANNEL
      )

      create(
        :user_notification_route,
        user: second_user,
        destination_community: community,
        channel_id: ESM::Community::ESM::SPAM_CHANNEL
      )

      results = nil
      expect { results = event_service.run! }.not_to raise_error

      expect(results.size).to eq(2)

      all_expected = results.all? { |_user, status| status[:custom_routes][:expected] == 1 && status[:custom_routes][:sent] == 1 }
      expect(all_expected).to eq(true)
    end

    it "sends (specific server)" do
      create(
        :user_notification_route,
        user: user,
        destination_community: community,
        source_server_id: server.id,
        channel_id: ESM::Community::ESM::SPAM_CHANNEL
      )

      create(
        :user_notification_route,
        user: second_user,
        destination_community: community,
        source_server_id: ESM::Test.server(for: community).id,
        channel_id: ESM::Community::ESM::SPAM_CHANNEL
      )

      results = nil
      expect { results = event_service.run! }.not_to raise_error

      expect(results.size).to eq(2)

      status = results[user]
      expect(status[:custom_routes][:expected]).to eq(1)
      expect(status[:custom_routes][:sent]).to eq(1)

      status = results[second_user]
      expect(status[:custom_routes][:expected]).to eq(0)
      expect(status[:custom_routes][:sent]).to eq(0)
    end
  end

  # <OpenStruct type="base-raid", recipients="{ \"r\": [\"76561198037177305\",\"76561198025434405\"] }", message="ESM Test", id="awesome">
  describe "#base-raid" do
    let(:attributes) do
      {
        type: "base-raid",
        recipients: recipients,
        message: territory.territory_name,
        id: territory.esm_custom_id || territory.id
      }
    end

    it "sends to all" do
      run_test(
        expected_messages: [
          {title: "Oh noes! #{attributes[:message]} is being raided!", description: "Hop on quick, **#{attributes[:message]}** (`#{attributes[:id]}`) is being raided"},
          {title: "Oh noes! #{attributes[:message]} is being raided!", description: "Hop on quick, **#{attributes[:message]}** (`#{attributes[:id]}`) is being raided"}
        ]
      )
    end

    it "logs" do
      run_test(
        log_xm8_event: true,
        expected_messages: [
          {title: "Oh noes! #{attributes[:message]} is being raided!", description: "Hop on quick, **#{attributes[:message]}** (`#{attributes[:id]}`) is being raided"},
          {title: "Oh noes! #{attributes[:message]} is being raided!", description: "Hop on quick, **#{attributes[:message]}** (`#{attributes[:id]}`) is being raided"},
          {
            title: "(Delivered) `#{attributes[:type]}` XM8 Notification for `#{server.server_id}`",
            description: "**Title:**\nOh noes! #{attributes[:message]} is being raided!\n**Description:**\nHop on quick, **#{attributes[:message]}** (`#{attributes[:id]}`) is being raided"
          }
        ]
      )
    end
  end

  # <OpenStruct type="flag-restored", recipients="{ \"r\": [\"76561198037177305\",\"76561198025434405\"] }", message="ESM Test", id="awesome">
  describe "#flag-restored" do
    let(:attributes) do
      {
        type: "flag-restored",
        recipients: recipients,
        message: territory.territory_name,
        id: territory.esm_custom_id || territory.id
      }
    end

    it "sends to all" do
      run_test(
        expected_messages: [
          {title: "Flag Restored `(#{attributes[:id]})`", description: "**#{attributes[:message]}'s** flag has been restored! Good job getting it back!"},
          {title: "Flag Restored `(#{attributes[:id]})`", description: "**#{attributes[:message]}'s** flag has been restored! Good job getting it back!"}
        ]
      )
    end

    it "logs" do
      run_test(
        log_xm8_event: true,
        expected_messages: [
          {title: "Flag Restored `(#{attributes[:id]})`", description: "**#{attributes[:message]}'s** flag has been restored! Good job getting it back!"},
          {title: "Flag Restored `(#{attributes[:id]})`", description: "**#{attributes[:message]}'s** flag has been restored! Good job getting it back!"},
          {
            title: "(Delivered) `#{attributes[:type]}` XM8 Notification for `#{server.server_id}`",
            description: "**Title:**\nFlag Restored `(#{attributes[:id]})`\n**Description:**\n**#{attributes[:message]}'s** flag has been restored! Good job getting it back!"
          }
        ]
      )
    end
  end

  # <OpenStruct type="flag-steal-started", recipients="{ \"r\": [\"76561198037177305\",\"76561198025434405\"] }", message="ESM Test", id="awesome">
  describe "#flag-steal-started" do
    let(:attributes) do
      {
        type: "flag-steal-started",
        recipients: recipients,
        message: territory.territory_name,
        id: territory.esm_custom_id || territory.id
      }
    end

    it "sends to all" do
      run_test(
        expected_messages: [
          {title: "Flag Steal Started `(#{attributes[:id]})`", description: "Someone is trying to steal **#{attributes[:message]}'s** flag!"},
          {title: "Flag Steal Started `(#{attributes[:id]})`", description: "Someone is trying to steal **#{attributes[:message]}'s** flag!"}
        ]
      )
    end

    it "logs" do
      run_test(
        log_xm8_event: true,
        expected_messages: [
          {title: "Flag Steal Started `(#{attributes[:id]})`", description: "Someone is trying to steal **#{attributes[:message]}'s** flag!"},
          {title: "Flag Steal Started `(#{attributes[:id]})`", description: "Someone is trying to steal **#{attributes[:message]}'s** flag!"},
          {
            title: "(Delivered) `#{attributes[:type]}` XM8 Notification for `#{server.server_id}`",
            description: "**Title:**\nFlag Steal Started `(#{attributes[:id]})`\n**Description:**\nSomeone is trying to steal **#{attributes[:message]}'s** flag!"
          }
        ]
      )
    end
  end

  # <OpenStruct type="flag-stolen", recipients="{ \"r\": [\"76561198037177305\",\"76561198025434405\"] }", message="ESM Test", id="awesome">
  describe "#flag-stolen" do
    let(:attributes) do
      {
        type: "flag-stolen",
        recipients: recipients,
        message: territory.territory_name,
        id: territory.esm_custom_id || territory.id
      }
    end

    it "sends to all" do
      run_test(
        expected_messages: [
          {title: "Flag Stolen `(#{attributes[:id]})`", description: "**#{attributes[:message]}'s** flag has been stolen! Go get it back!"},
          {title: "Flag Stolen `(#{attributes[:id]})`", description: "**#{attributes[:message]}'s** flag has been stolen! Go get it back!"}
        ]
      )
    end

    it "logs" do
      run_test(
        log_xm8_event: true,
        expected_messages: [
          {title: "Flag Stolen `(#{attributes[:id]})`", description: "**#{attributes[:message]}'s** flag has been stolen! Go get it back!"},
          {title: "Flag Stolen `(#{attributes[:id]})`", description: "**#{attributes[:message]}'s** flag has been stolen! Go get it back!"},
          {
            title: "(Delivered) `#{attributes[:type]}` XM8 Notification for `#{server.server_id}`",
            description: "**Title:**\nFlag Stolen `(#{attributes[:id]})`\n**Description:**\n**#{attributes[:message]}'s** flag has been stolen! Go get it back!"
          }
        ]
      )
    end
  end

  # <OpenStruct type="grind-started", recipients="{ \"r\": [\"76561198037177305\",\"76561198025434405\"] }", message="ESM Test",id="awesome">
  describe "#grind-started" do
    let(:attributes) do
      {
        type: "grind-started",
        recipients: recipients,
        message: territory.territory_name,
        id: territory.esm_custom_id || territory.id
      }
    end

    it "sends to all" do
      run_test(
        expected_messages: [
          {title: "Grinding Started `(#{attributes[:id]})`", description: "Some scalliwag is tryna grind yer locks! **#{attributes[:message]}** is being raided!"},
          {title: "Grinding Started `(#{attributes[:id]})`", description: "Some scalliwag is tryna grind yer locks! **#{attributes[:message]}** is being raided!"}
        ]
      )
    end

    it "logs" do
      run_test(
        log_xm8_event: true,
        expected_messages: [
          {title: "Grinding Started `(#{attributes[:id]})`", description: "Some scalliwag is tryna grind yer locks! **#{attributes[:message]}** is being raided!"},
          {title: "Grinding Started `(#{attributes[:id]})`", description: "Some scalliwag is tryna grind yer locks! **#{attributes[:message]}** is being raided!"},
          {
            title: "(Delivered) `#{attributes[:type]}` XM8 Notification for `#{server.server_id}`",
            description: "**Title:**\nGrinding Started `(#{attributes[:id]})`\n**Description:**\nSome scalliwag is tryna grind yer locks! **#{attributes[:message]}** is being raided!"
          }
        ]
      )
    end
  end

  # <OpenStruct type="hack-started", recipients="{ \"r\": [\"76561198037177305\",\"76561198025434405\"] }", message="ESM Test", id="awesome">
  describe "#hack-started" do
    let(:attributes) do
      {
        type: "hack-started",
        recipients: recipients,
        message: territory.territory_name,
        id: territory.esm_custom_id || territory.id
      }
    end

    it "sends to all" do
      run_test(
        expected_messages: [
          {title: "Hacking Started `(#{attributes[:id]})`", description: "H4x0rs are trying to get into your stuff! **#{attributes[:message]}** is being robbed! "},
          {title: "Hacking Started `(#{attributes[:id]})`", description: "H4x0rs are trying to get into your stuff! **#{attributes[:message]}** is being robbed! "}
        ]
      )
    end

    it "logs" do
      run_test(
        log_xm8_event: true,
        expected_messages: [
          {title: "Hacking Started `(#{attributes[:id]})`", description: "H4x0rs are trying to get into your stuff! **#{attributes[:message]}** is being robbed! "},
          {title: "Hacking Started `(#{attributes[:id]})`", description: "H4x0rs are trying to get into your stuff! **#{attributes[:message]}** is being robbed! "},
          {
            title: "(Delivered) `#{attributes[:type]}` XM8 Notification for `#{server.server_id}`",
            description: "**Title:**\nHacking Started `(#{attributes[:id]})`\n**Description:**\nH4x0rs are trying to get into your stuff! **#{attributes[:message]}** is being robbed! "
          }
        ]
      )
    end
  end

  # <OpenStruct type="protection-money-paid", recipients="{ \"r\": [\"76561198037177305\",\"76561198025434405\"] }", message="ESM Test", id="awesome">
  describe "#protection-money-paid" do
    let(:attributes) do
      {
        type: "protection-money-paid",
        recipients: recipients,
        message: territory.territory_name,
        id: territory.esm_custom_id || territory.id
      }
    end

    it "sends to all" do
      run_test(
        expected_messages: [
          {title: "Protection Money Paid `(#{attributes[:id]})`", description: "**#{attributes[:message]}'s** protection money has been paid"},
          {title: "Protection Money Paid `(#{attributes[:id]})`", description: "**#{attributes[:message]}'s** protection money has been paid"}
        ]
      )
    end

    it "logs" do
      run_test(
        log_xm8_event: true,
        expected_messages: [
          {title: "Protection Money Paid `(#{attributes[:id]})`", description: "**#{attributes[:message]}'s** protection money has been paid"},
          {title: "Protection Money Paid `(#{attributes[:id]})`", description: "**#{attributes[:message]}'s** protection money has been paid"},
          {
            title: "(Delivered) `#{attributes[:type]}` XM8 Notification for `#{server.server_id}`",
            description: "**Title:**\nProtection Money Paid `(#{attributes[:id]})`\n**Description:**\n**#{attributes[:message]}'s** protection money has been paid"
          }
        ]
      )
    end
  end

  # <OpenStruct type="marxet-item-sold", recipients="{ \"r\": [\"76561198037177305\"] }", message="{ \"item\": \"MX 6.5mm\", \"amount\": \"1000\" }">
  describe "#marxet-item-sold" do
    let(:attributes) do
      {
        type: "marxet-item-sold",
        recipients: recipients,
        message: {item: Faker::Book.title, amount: Faker::Number.between(from: 1, to: 10_000_000)}.to_json,
        id: territory.esm_custom_id || territory.id
      }
    end

    it "sends to all" do
      values = attributes[:message].to_ostruct

      run_test(
        expected_messages: [
          {title: "Item sold on MarXet", description: "You just sold **#{values.item}** for **#{values.amount}** poptabs"},
          {title: "Item sold on MarXet", description: "You just sold **#{values.item}** for **#{values.amount}** poptabs"}
        ]
      )
    end

    it "logs" do
      values = attributes[:message].to_ostruct

      run_test(
        log_xm8_event: true,
        expected_messages: [
          {title: "Item sold on MarXet", description: "You just sold **#{values.item}** for **#{values.amount}** poptabs"},
          {title: "Item sold on MarXet", description: "You just sold **#{values.item}** for **#{values.amount}** poptabs"},
          {
            title: "(Delivered) `#{attributes[:type]}` XM8 Notification for `#{server.server_id}`",
            description: "**Title:**\nItem sold on MarXet\n**Description:**\nYou just sold **#{values.item}** for **#{values.amount}** poptabs"
          }
        ]
      )
    end
  end

  # <OpenStruct type="custom", recipients="{ \"r\": [\"76561198037177305\"] }", message="{ \"title\": \"Hello\", \"body\": \"World\" }">
  describe "#custom" do
    let(:attributes) do
      {
        type: "custom",
        recipients: recipients,
        message: {title: Faker::Beer.name, body: Faker::Artist.name},
        id: territory.esm_custom_id || territory.id
      }
    end

    it "sends to all" do
      values = attributes[:message].to_ostruct

      run_test(
        expected_messages: [
          {title: values[:title], description: values[:body]},
          {title: values[:title], description: values[:body]}
        ]
      )
    end

    it "logs" do
      values = attributes[:message].to_ostruct

      run_test(
        log_xm8_event: true,
        expected_messages: [
          {title: values[:title], description: values[:body]},
          {title: values[:title], description: values[:body]},
          {
            title: "(Delivered) `#{attributes[:type]}` XM8 Notification for `#{server.server_id}`",
            description: "**Title:**\n#{values[:title]}\n**Description:**\n#{values[:body]}"
          }
        ]
      )
    end
  end
end
