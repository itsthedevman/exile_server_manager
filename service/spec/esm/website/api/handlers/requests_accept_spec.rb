# frozen_string_literal: true

RSpec.describe ESM::Website::API::Handlers::RequestsAccept do
  describe ".call" do
    context "when the request exists" do
      let(:user) { create(:user) }
      let!(:request) do
        create(
          :request,
          requestor_user_id: user.id,
          requestee_user_id: user.id,
          expires_at: 1.day.from_now
        )
      end

      it "responds with accepted=true" do
        expect_any_instance_of(ESM::Request).to receive(:respond).with(true)
        described_class.call(id: request.id)
      end
    end

    context "when the request is missing" do
      it "returns nil without raising" do
        expect(described_class.call(id: -1)).to be_nil
      end
    end
  end
end
