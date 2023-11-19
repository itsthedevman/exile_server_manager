# frozen_string_literal: true

describe ESM::Command::Server::Logs, category: "command" do
  include_context "command"
  include_examples "validate_command"

  describe "#execute" do
    include_context "connection_v1"

    before do
      grant_command_access!(community, "logs")
    end

    context "when the target is a steam uid" do
      it "returns a link to the results" do
        execute!(arguments: {server_id: server.server_id, target: second_user.steam_uid})

        wait_for { connection.requests }.to be_blank
        wait_for { ESM::Test.messages.size }.to eq(1)

        embed = ESM::Test.messages.first.content
        expect(embed.description).to match(
          /you may review the results here:\shttp:\/\/localhost:3000\/logs\/.+\s+_link expires on `.+`_/i
        )

        expect(ESM::Log.all.size).to eq(1)
        expect(ESM::Log.all.first.search_text).to eq(second_user.steam_uid)
        expect(ESM::LogEntry.all.size).not_to eq(0)

        ESM::LogEntry.all.each do |entry|
          expect(entry.entries).not_to be_empty
        end
      end
    end

    context "when the target is a text query" do
      it "returns a link to the results" do
        execute!(arguments: {server_id: server.server_id, target: "testing"})

        wait_for { connection.requests }.to be_blank
        wait_for { ESM::Test.messages.size }.to eq(1)

        embed = ESM::Test.messages.first.content
        expect(embed.description).to match(
          /you may review the results here:\shttp:\/\/localhost:3000\/logs\/.+\s+_link expires on `.+`_/i
        )

        expect(ESM::Log.all.size).to eq(1)
        expect(ESM::Log.all.first.search_text).to eq("testing")
        expect(ESM::LogEntry.all.size).not_to eq(0)

        ESM::LogEntry.all.each do |entry|
          expect(entry.entries).not_to be_empty
        end
      end
    end

    context "when there are no results" do
      it "sends a message to the user telling them" do
        wsc.flags.NO_LOGS = true

        execute!(arguments: {server_id: server.server_id, target: "testing"})
        wait_for { connection.requests }.to be_blank
        wait_for { ESM::Test.messages.size }.to eq(1)

        embed = ESM::Test.messages.first.content
        expect(embed.description).to match(/hey .+, i was unable to find any logs that match your query./i)
      end
    end

    context "when the target is an un-registered steam uid" do
      it "should work with a non-registered steam uid" do
        steam_uid = second_user.steam_uid
        second_user.update(steam_uid: "")

        execute!(arguments: {server_id: server.server_id, target: steam_uid})

        wait_for { connection.requests }.to be_blank
        wait_for { ESM::Test.messages.size }.to eq(1)

        embed = ESM::Test.messages.first.content
        expect(embed.description).to match(/you may review the results here:\shttp:\/\/localhost:3000\/logs\/.+\s+_link expires on `.+`_/i)

        expect(ESM::Log.all.size).to eq(1)
        expect(ESM::Log.all.first.search_text).to eq(steam_uid)
        expect(ESM::LogEntry.all.size).not_to eq(0)

        ESM::LogEntry.all.each do |entry|
          expect(entry.entries).not_to be_empty
        end
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

    it "parses German months" do
      checker(german_months)
    end

    it "parses Italian months" do
      checker(italian_months)
    end

    it "parses Spanish months" do
      checker(spanish_months)
    end

    it "parses French months" do
      checker(french_months)
    end
  end
end
