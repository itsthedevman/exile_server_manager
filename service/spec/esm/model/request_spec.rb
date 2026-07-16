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
    it "persists the accepted status" do
      request.accept!
      expect(request.reload.accepted?).to be(true)
    end

    it "keeps the request around after responding" do
      expect { request.accept! }.not_to change(ESM::Request, :count)
    end
  end

  describe "#reject!" do
    it "persists the rejected status" do
      request.reject!
      expect(request.reload.rejected?).to be(true)
    end

    it "keeps the request around after responding" do
      expect { request.reject! }.not_to change(ESM::Request, :count)
    end
  end
end
