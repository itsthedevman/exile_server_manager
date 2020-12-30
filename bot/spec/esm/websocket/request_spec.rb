# frozen_string_literal: true

describe ESM::Websocket::Request do
  it "should accept string for command name" do
    request = ESM::Websocket::Request.new(
      command_name: "testing",
      user: nil,
      parameters: nil,
      channel: nil
    )

    expect(request).not_to be_nil
    expect(request.command_name).to eql("testing")
  end

  it "should accept ESM::Command for command" do
    request = ESM::Websocket::Request.new(
      command: ESM::Command::Test::Base.new,
      user: nil,
      parameters: nil,
      channel: nil
    )

    expect(request).not_to be_nil
    expect(request.command_name).to eql("base")
  end

  it "should accept nil for user" do
    request = ESM::Websocket::Request.new(
      command_name: "testing",
      user: nil,
      parameters: nil,
      channel: nil
    )

    expect(request).not_to be_nil
    expect(request.user).to be_nil
    expect(request.user_info).to eql(["", ""])
  end

  it "should accept a valid user" do
    user = ESM.bot.user(TestUser::User1::ID)
    request = ESM::Websocket::Request.new(
      command_name: "testing",
      user: user,
      parameters: nil,
      channel: nil
    )

    expect(request).not_to be_nil
    expect(request.user).not_to be_nil
    expect(request.user_info).to eql([user.mention, user.id])
  end

  describe "#to_s" do
    it "should be valid" do
      params = {
        foo: "Foo",
        bar: ["Bar"],
        baz: false
      }

      request = create_request(params)
      user = request.user

      valid_hash_string = {
        "command" => "base",
        "commandID" => request.id,
        "authorInfo" => [user.mention, user.id],
        "parameters" => params
    }.to_json

      expect(request.to_s).to eql(valid_hash_string)
    end
  end

  describe "#timed_out?" do
    it "should be timed out" do
      request = ESM::Websocket::Request.new(command_name: "testing", user: nil, channel: nil, command: nil, parameters: nil, timeout: 0)
      expect(request.timed_out?).to be(true)
    end

    it "should not be timed out" do
      request = ESM::Websocket::Request.new(command_name: "testing", user: nil, channel: nil, command: nil, parameters: nil)
      expect(request.timed_out?).to be(false)
    end
  end
end
