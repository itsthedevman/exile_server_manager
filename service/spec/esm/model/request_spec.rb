# frozen_string_literal: true

RSpec.describe ESM::Request do
  let!(:user_1) { create(:user) }
  let!(:user_2) { create(:user) }

  let!(:request) do
    create(
      :request,
      requestor_user_id: user_1.id,
      requestee_user_id: user_2.id,
      requested_from_channel_id: Spec::Snowflake.next,
      command_name: "id"
    )
  end

  describe "status" do
    it "defaults to pending" do
      expect(request.reload.pending?).to be(true)
    end
  end

  describe "scope#expired" do
    it "returns expired requests" do
      request.update!(expires_at: Time.current - 1.day)
      expect(ESM::Request.expired).to contain_exactly(request)
    end
  end

  describe "scope#accepted" do
    it "returns only accepted requests" do
      expect(ESM::Request.accepted).to be_empty

      request.update!(status: :accepted)
      expect(ESM::Request.accepted).to contain_exactly(request)
    end
  end

  describe "scope#rejected" do
    it "returns only rejected requests" do
      expect(ESM::Request.rejected).to be_empty

      request.update!(status: :rejected)
      expect(ESM::Request.rejected).to contain_exactly(request)
    end
  end

  describe "#accept!" do
    it "marks the request accepted" do
      request.accept!
      expect(request.accepted?).to be(true)
    end

    it "responds to the request and removes it" do
      expect { request.accept! }.to change(ESM::Request, :count).by(-1)
    end
  end

  describe "#reject!" do
    it "marks the request rejected" do
      request.reject!
      expect(request.rejected?).to be(true)
    end

    it "responds to the request and removes it" do
      expect { request.reject! }.to change(ESM::Request, :count).by(-1)
    end
  end
end
