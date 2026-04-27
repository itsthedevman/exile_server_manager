# frozen_string_literal: true

describe ESM::Command::Request::Accept, category: "command" do
  include_context "command"
  include_examples "validate_command"

  describe "#execute" do
    let!(:user_2) { ESM::Test.user }

    let!(:request) do
      create(
        :request,
        requestor_user_id: user.id,
        requestee_user_id: user_2.id,
        requested_from_channel_id: ESM::Test.channel(in: community).id,
        command_name: "id"
      )
    end

    context "when the request is for this user" do
      it "accepts the request" do
        execute!(user: user_2, channel_type: :dm, arguments: {uuid: request.uuid_short})

        expect(ESM::Test.messages).to be_empty
        expect(ESM::Request.all.size).to eq(0)
      end
    end

    context "when the request is for a different user" do
      it "raises an exception" do
        # The uuid is valid, but the user is not the who the request is for
        execution_args = {user: user, channel_type: :dm, arguments: {uuid: request.uuid_short}}

        expect { execute!(**execution_args) }.to raise_error(ESM::Exception::CheckFailure, /unable to find a request/i)
      end
    end
  end
end
