# frozen_string_literal: true

describe ESM::Command::My::Preferences, category: "command" do
  include_context "command"
  include_examples "validate_command"

  describe "#execute" do
    let!(:types) { ESM::Command::My::Preferences::TYPES.dup[1..] }
    let(:type) { types.sample }
    let(:preference) { ESM::UserNotificationPreference.where(server_id: server.id, user_id: user.id).first }

    context "when the action is allow and type is omitted" do
      it "sets all permission for the server to allowed" do
        execute!(channel_type: :dm, arguments: {server_id: server.server_id, action: "allow"})

        message = ESM::Test.messages.first.content
        expect(message).not_to be_nil
        expect(message.description).to match(/your preferences for `.+` have been updated/i)

        types.each do |type|
          expect(preference.send(type.underscore)).to be(true)
        end
      end
    end

    context "when the action is allow and the type is provided" do
      it "sets the permission type for the server to allowed" do
        execute!(channel_type: :dm, arguments: {server_id: server.server_id, action: "allow", type: type})

        message = ESM::Test.messages.first.content
        expect(message).not_to be_nil
        expect(message.description).to match(/your preferences for `.+` have been updated/i)

        expect(preference.send(type.underscore)).to be(true)
      end
    end

    context "when the action is deny and the type is omitted" do
      it "sets all permissions for the server to deny" do
        execute!(channel_type: :dm, arguments: {server_id: server.server_id, action: "deny"})

        message = ESM::Test.messages.first.content
        expect(message).not_to be_nil
        expect(message.description).to match(/your preferences for `.+` have been updated/i)

        types.each do |type|
          expect(preference.send(type.underscore)).to be(false)
        end
      end
    end

    context "when the action is deny and the type is provided" do
      it "sets the permission type for the server to denied" do
        execute!(channel_type: :dm, arguments: {server_id: server.server_id, action: "deny", type: type})

        message = ESM::Test.messages.first.content
        expect(message).not_to be_nil
        expect(message.description).to match(/your preferences for `.+` have been updated/i)

        expect(preference.send(type.underscore)).to be(false)
      end
    end
  end
end
