# frozen_string_literal: true

describe ESM::Request do
  let!(:user_1) { create(:user) }
  let!(:user_2) { create(:user) }
  let(:request) do
    create(
      :request,
      requestor_user_id: user_1.id,
      requestee_user_id: user_2.id,
      requested_from_channel_id: Spec::Snowflake.next,
      command_name: "id"
    )
  end

  describe "scope#expired" do
    it "returns expired requests" do
      request.update(expires_at: Time.current - 1.day)
      expect(ESM::Request.expired.size).to eq(1)
    end
  end

  describe "#respond" do
    it "is accepted" do
      expect { request.respond(true) }.not_to raise_error
      expect(request.accepted).to be(true)
    end

    it "is denied" do
      expect { request.respond(false) }.not_to raise_error
      expect(request.accepted).to be(false)
    end

    it "responds" do
      expect { request.respond(true) }.not_to raise_error
      expect(ESM::Request.all.size).to eq(0)
    end
  end
end
