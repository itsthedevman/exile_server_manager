# frozen_string_literal: true

describe "Territory ID decoding", :requires_connection do
  include_context "connection"

  let!(:territory) do
    owner_uid = ESM::Test.steam_uid
    create(
      :exile_territory,
      owner_uid: owner_uid,
      moderators: [owner_uid],
      build_rights: [owner_uid],
      server_id: server.id
    )
  end

  before do
    # Create a dummy function to call
    execute_sqf! <<~SQF
      missionNamespace setVariable [
        "MyDummyFunction",
        {
          [[(_this get "id")]] call ESMs_util_command_handleSuccess;
        }
      ];
    SQF
  end

  after do
    # And cleanup the function
    execute_sqf!("missionNamespace setVariable ['MyDummyFunction', nil];")
  end

  context "when the value is a valid encoded territory ID" do
    it "decodes it and completes the request" do
      message = ESM::Message.new.set_type(:call)
        .set_data(
          function_name: "MyDummyFunction",
          territory_id: territory.encoded_id
        )

      expect { server.send_message(message) }.not_to raise_error
    end
  end

  context "when the value is a valid custom territory ID" do
    before do
      territory.update!(esm_custom_id: "my_custom_id")
    end

    it "decodes it and completes the request" do
      message = ESM::Message.new.set_type(:call)
        .set_data(
          function_name: "MyDummyFunction",
          territory_id: territory.esm_custom_id
        )

      expect { server.send_message(message) }.not_to raise_error
    end
  end

  context "when the value is not a valid encoded territory ID" do
    it "fails to decode" do
      message = ESM::Message.new.set_type(:call)
        .set_data(territory_id: "gibberish") # function is not needed for this test

      expectation = expect { server.send_message(message) }
      expectation.to raise_error(ESM::Exception::ExtensionError) do |error|
        expect(error.data.description).to match("I was unable to find an active territory")
      end
    end
  end
end
