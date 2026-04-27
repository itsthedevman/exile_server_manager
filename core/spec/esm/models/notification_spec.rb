# frozen_string_literal: true

RSpec.describe ESM::Notification do
  let!(:community) { create(:community) }

  describe "CATEGORIES" do
    it "defines notification categories" do
      expect(described_class::CATEGORIES).to include("xm8")
      expect(described_class::CATEGORIES).to include("gambling")
      expect(described_class::CATEGORIES).to include("player")
    end
  end

  describe "TYPES" do
    it "defines XM8 notification types" do
      expect(described_class::TYPES).to include("base-raid")
      expect(described_class::TYPES).to include("flag-stolen")
      expect(described_class::TYPES).to include("protection-money-due")
    end

    it "defines gambling notification types" do
      expect(described_class::TYPES).to include("loss")
      expect(described_class::TYPES).to include("won")
    end

    it "defines player notification types" do
      expect(described_class::TYPES).to include("money")
      expect(described_class::TYPES).to include("locker")
      expect(described_class::TYPES).to include("respect")
    end
  end

  describe "DEFAULTS" do
    it "loads from YAML file" do
      expect(described_class::DEFAULTS).to be_a(Hash)
    end

    it "is frozen" do
      expect(described_class::DEFAULTS).to be_frozen
    end
  end

  describe "scopes" do
    let!(:xm8_notification) do
      create(:notification, community: community,
        notification_category: "xm8",
        notification_type: "base-raid")
    end

    let!(:gambling_notification) do
      create(:notification, community: community,
        notification_category: "gambling",
        notification_type: "won")
    end

    describe ".with_category" do
      it "filters by category" do
        result = described_class.with_category("xm8")

        expect(result).to include(xm8_notification)
        expect(result).not_to include(gambling_notification)
      end
    end

    describe ".with_type" do
      it "filters by type" do
        result = described_class.with_type("base-raid")

        expect(result).to include(xm8_notification)
        expect(result).not_to include(gambling_notification)
      end
    end

    describe ".with_any_type" do
      it "filters by multiple types" do
        result = described_class.with_any_type("base-raid", "won")

        expect(result).to include(xm8_notification)
        expect(result).to include(gambling_notification)
      end
    end
  end

  describe "callbacks" do
    describe "before_create :generate_public_id" do
      it "generates a UUID on create" do
        notification = create(:notification, community: community)

        expect(notification.public_id).to be_present
        expect(notification.public_id).to match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/)
      end

      it "does not overwrite existing public_id" do
        existing_id = SecureRandom.uuid
        notification = create(:notification, community: community, public_id: existing_id)

        expect(notification.public_id).to eq(existing_id)
      end
    end
  end

  describe "associations" do
    it "belongs to a community" do
      notification = create(:notification, community: community)
      expect(notification.community).to eq(community)
    end
  end
end
