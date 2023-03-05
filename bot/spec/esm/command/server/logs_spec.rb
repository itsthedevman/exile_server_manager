# frozen_string_literal: true

describe ESM::Command::Server::Logs, category: "command" do
  let!(:command) { ESM::Command::Server::Logs.new }

  it "should be valid" do
    expect(command).not_to be_nil
  end

  it "should have 2 argument" do
    expect(command.arguments.size).to eq(2)
  end

  it "should have a description" do
    expect(command.description).not_to be_blank
  end

  it "should have examples" do
    expect(command.example).not_to be_blank
  end

  describe "#execute" do
    let!(:community) { ESM::Test.community }
    let!(:server) { ESM::Test.server }
    let!(:user) { ESM::Test.user }

    let(:second_user) { ESM::Test.user }

    let!(:wsc) { WebsocketClient.new(server) }
    let(:connection) { ESM::Websocket.connections[server.server_id] }
    let(:response) { command.response }

    before :each do
      wait_for { wsc.connected? }.to be(true)

      grant_command_access!(community, "logs")
    end

    after :each do
      wsc.disconnect!
    end

    it "!logs <server_id> <target>" do
      command_statement = command.statement(server_id: server.server_id, target: second_user.steam_uid)
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      expect { command.execute(event) }.not_to raise_error
      wait_for { connection.requests }.to be_blank
      expect(ESM::Test.messages.size).to eq(1)
      embed = ESM::Test.messages.first.second

      expect(embed.description).to match(/you may review the results here:\shttp:\/\/localhost:3000\/logs\/.+\s+_link expires on `.+`_/i)

      expect(ESM::Log.all.size).to eq(1)
      expect(ESM::Log.all.first.search_text).to eq(second_user.steam_uid)
      expect(ESM::LogEntry.all.size).not_to eq(0)

      ESM::LogEntry.all.each do |entry|
        expect(entry.entries).not_to be_empty
      end
    end

    it "!logs <server_id> <query>" do
      command_statement = command.statement(server_id: server.server_id, target: "testing")
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      expect { command.execute(event) }.not_to raise_error
      wait_for { connection.requests }.to be_blank
      expect(ESM::Test.messages.size).to eq(1)
      embed = ESM::Test.messages.first.second

      expect(embed.description).to match(/you may review the results here:\shttp:\/\/localhost:3000\/logs\/.+\s+_link expires on `.+`_/i)

      expect(ESM::Log.all.size).to eq(1)
      expect(ESM::Log.all.first.search_text).to eq("testing")
      expect(ESM::LogEntry.all.size).not_to eq(0)

      ESM::LogEntry.all.each do |entry|
        expect(entry.entries).not_to be_empty
      end
    end

    it "should handle no logs" do
      wsc.flags.NO_LOGS = true

      command_statement = command.statement(server_id: server.server_id, target: "testing")
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      expect { command.execute(event) }.not_to raise_error
      wait_for { connection.requests }.to be_blank
      expect(ESM::Test.messages.size).to eq(1)
      embed = ESM::Test.messages.first.second

      expect(embed.description).to match(/hey .+, i was unable to find any logs that match your query./i)
    end

    it "should work with a non-registered steam uid" do
      steam_uid = second_user.steam_uid
      second_user.update(steam_uid: "")

      command_statement = command.statement(server_id: server.server_id, target: steam_uid)
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      expect { command.execute(event) }.not_to raise_error
      wait_for { connection.requests }.to be_blank
      expect(ESM::Test.messages.size).to eq(1)
      embed = ESM::Test.messages.first.second

      expect(embed.description).to match(/you may review the results here:\shttp:\/\/localhost:3000\/logs\/.+\s+_link expires on `.+`_/i)

      expect(ESM::Log.all.size).to eq(1)
      expect(ESM::Log.all.first.search_text).to eq(steam_uid)
      expect(ESM::LogEntry.all.size).not_to eq(0)

      ESM::LogEntry.all.each do |entry|
        expect(entry.entries).not_to be_empty
      end
    end
  end

  describe "#parse_log_entry_date" do
    let(:german_months) { %w[Januar Februar März April Mai Juni Juli August September Oktober November Dezember] }
    let(:italian_months) { %w[Gennaio Febbraio Marzo Aprile Maggio Giugno Luglio Agosto Settembre Ottobre Novembre Dicembre] }
    let(:spanish_months) { %w[Enero Febrero Marzo Abril Mayo Junio Julio Agosto Septiembre Octubre Noviembre Diciembre] }
    let(:french_months) { %w[Janvier Février Mars Avril Mai Juin Juillet Août Septembre Octobre Novembre Décembre] }

    def checker(months)
      months.each_with_index do |month, index|
        entry = OpenStruct.new(date: "#{month} #{Faker::Number.between(from: 1, to: 20)} #{Faker::Number.between(from: 2000, to: 2100)}")
        date = nil
        expect { date = command.send(:parse_log_entry_date, entry) }.not_to raise_error
        expect(date.month).to eq(index + 1)
      end
    end

    it "should parse German months" do
      checker(german_months)
    end

    it "should parse Italian months" do
      checker(italian_months)
    end

    it "should parse Spanish months" do
      checker(spanish_months)
    end

    it "should parse French months" do
      checker(french_months)
    end
  end
end
