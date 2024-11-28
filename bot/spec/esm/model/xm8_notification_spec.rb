# frozen_string_literal: true

describe ESM::Xm8Notification do
  let(:user) { ESM::Test.user }
  let(:second_user) { ESM::Test.user }
  let(:server) { ESM::Test.server(for: ESM::Test.community) }

  let(:recipient_notification_mapping) do
    {
      user => SecureRandom.uuid,
      second_user => SecureRandom.uuid
    }
  end

  subject(:notification) do
    described_class.new(
      recipient_notification_mapping:,
      server:,
      content: {},
      created_at: Time.current
    )
  end

  describe ".from" do
    let(:type) {}
    let(:data) { {territory_name: Faker::String.random, territory_id: Faker::String.random} }

    let(:notification_hash) do
      {
        type:,
        server:,
        recipient_notification_mapping:,
        content: data.to_json,
        created_at: Faker::Time.forward.strftime(ESM::Time::Format::SQL_TIME)
      }
    end

    subject(:notification) { described_class.from(notification_hash) }

    context "when content is valid" do
      let!(:type) { "base-raid" }

      it "is expected to convert the content to a hash" do
        expect(notification.content.to_h).to eq(data)
      end
    end

    context "when content is invalid" do
      let!(:type) { "foobar" }

      it "is expected to raise NameError" do
        expect { notification }.to raise_error(
          ESM::Xm8Notification::InvalidType, "\"foobar\" is not a valid XM8 notification type"
        )
      end
    end

    context "when the type is base-raid" do
      let!(:type) { "base-raid" }

      it { is_expected.to be_instance_of(described_class::BaseRaid) }
    end

    context "when the type is charge-plant-started" do
      let!(:type) { "charge-plant-started" }

      it { is_expected.to be_instance_of(described_class::ChargePlantStarted) }
    end

    context "when the type is custom" do
      let!(:type) { "custom" }
      let!(:data) { {title: Faker::String.random, description: Faker::String.random} }

      it { is_expected.to be_instance_of(described_class::Custom) }
    end

    context "when the type is flag-restored" do
      let!(:type) { "flag-restored" }

      it { is_expected.to be_instance_of(described_class::FlagRestored) }
    end

    context "when the type is flag-restored" do
      let!(:type) { "flag-restored" }

      it { is_expected.to be_instance_of(described_class::FlagRestored) }
    end

    context "when the type is flag-steal-started" do
      let!(:type) { "flag-steal-started" }

      it { is_expected.to be_instance_of(described_class::FlagStealStarted) }
    end

    context "when the type is flag-stolen" do
      let!(:type) { "flag-stolen" }

      it { is_expected.to be_instance_of(described_class::FlagStolen) }
    end

    context "when the type is grind-started" do
      let!(:type) { "grind-started" }

      it { is_expected.to be_instance_of(described_class::GrindStarted) }
    end

    context "when the type is hack-started" do
      let!(:type) { "hack-started" }

      it { is_expected.to be_instance_of(described_class::HackStarted) }
    end

    context "when the type is marxet-item-sold" do
      let!(:type) { "marxet-item-sold" }
      let!(:data) { {item_name: Faker::String.random, poptabs_received: Faker::String.random} }

      it { is_expected.to be_instance_of(described_class::MarxetItemSold) }
    end

    context "when the type is protection-money-due" do
      let!(:type) { "protection-money-due" }

      it { is_expected.to be_instance_of(described_class::ProtectionMoneyDue) }
    end

    context "when the type is protection-money-paid" do
      let!(:type) { "protection-money-paid" }

      it { is_expected.to be_instance_of(described_class::ProtectionMoneyPaid) }
    end
  end
end
