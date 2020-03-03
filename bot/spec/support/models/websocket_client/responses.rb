# frozen_string_literal: true

class WebsocketClient
  module Responses
    CONFIG = {
      post_initialization: {},
      me: { delay: 0..2 },
      territories: { delay: 0..2 },
      pay: { send_ignore_message: true, delay: 0..5 }
    }.freeze

    def response_post_initialization
      @connected = true
      send_response(commandID: @data.commandID, ignore: true)
      @server_id = @data.parameters.server_id
    end

    def response_me
      territories = {}

      if rand < 0.5
        Faker::Number.within(range: 1..3).times do
          territories[Faker::FunnyName.two_word_name] = Faker::Crypto.md5[0, 3]
        end
      end

      send_response(
        commandID: @data.commandID,
        parameters: {
          locker: Faker::Number.within(range: 1..30_000),
          score: Faker::Number.within(range: 1..30_000),
          name: Faker::Internet.username,
          money: Faker::Number.within(range: 1..30_000),
          damage: Faker::Number.within(range: 1..100),
          hunger: Faker::Number.within(range: 1..100),
          thirst: Faker::Number.within(range: 1..100),
          kills: Faker::Number.within(range: 1..100),
          deaths: Faker::Number.within(range: 1..100),
          territories: territories
        }
      )
    end

    def response_territories
      return send_response(commandID: @data.commandID, parameters: []) if @flags.RETURN_NO_TERRITORIES

      # One static to test large amounts of moderators
      territories = [
        TerritoryGenerator.generate(moderator_count: 60)
      ]

      # Some random ones
      Faker::Number.within(range: 1..5).times do
        territories << TerritoryGenerator.generate
      end

      send_response(commandID: @data.commandID, parameters: territories)
    end

    def response_pay
      send_response(
        commandID: @data.commandID,
        parameters: [{
          payment: Faker::Number.between(from: 20, to: 600),
          locker: Faker::Number.between(from: 2000, to: 1_000_000_000)
        }]
      )
    end
  end
end
