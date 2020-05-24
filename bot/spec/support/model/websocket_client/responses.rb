# frozen_string_literal: true

class WebsocketClient
  module Responses
    # This controls how the websocket server treats the command.
    # Valid options:
    #   send_ignore_message [Boolean] Does this command need to send the ignore message. This matches the expected behavior from the DLL
    #   delay [Range] Delay sending the response by some random number between this range (in seconds). Simulates the delay from the Arma server
    CONFIG = {
      server_success_command: {},
      server_error_command: {},
      post_initialization: {},
      me: { delay: 0..1 },
      territories: { delay: 0..1 },
      pay: { send_ignore_message: true, delay: 0..3 },
      gamble: { send_ignore_message: true, delay: 0..3 },
      setterritoryid: { delay: 0..1 },
      add: { send_ignore_message: true, delay: 0..3 },
      allterritories: { send_ignore_message: true, delay: 0..3 },
      exec: { send_ignore_message: true, delay: 0..3 },
      promote: { send_ignore_message: true, delay: 0..3 },
      remove: { send_ignore_message: true, delay: 0..3 }
    }.freeze

    def response_server_success_command
      send_response
    end

    def response_server_error_command
      send_response(parameters: [{ error: "oops" }])
    end

    def response_post_initialization
      @connected = true
      send_ignore_message
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
      return send_response if @flags.RETURN_NO_TERRITORIES

      # One static to test large amounts of moderators
      territories = [
        TerritoryGenerator.generate(moderator_count: 60)
      ]

      # Some random ones
      Faker::Number.within(range: 1..5).times do
        territories << TerritoryGenerator.generate
      end

      send_response(parameters: territories)
    end

    def response_pay
      send_response(
        parameters: [{
          payment: Faker::Number.between(from: 20, to: 600),
          locker: Faker::Number.between(from: 2000, to: 1_000_000_000)
        }]
      )
    end

    def response_gamble
      return send_response(parameters: [{ error: "Not enough poptabs!" }]) if @flags.NOT_ENOUGH_MONEY

      amount = @data.parameters.amount.to_i
      locker_before = amount

      if rand > 0.50
        type = "won"
        locker_after = locker_before + amount
      else
        type = "loss"
        locker_after = locker_before - amount
      end

      send_response(
        parameters: [{
          type: type,
          amount: amount,
          locker_before: locker_before,
          locker_after: locker_after
        }]
      )
    end

    # The command is actually !setid, but the v1 DLL is expecting this.
    def response_setterritoryid
      return send_response(parameters: [{ success: false, reason: "Some reason" }]) if @flags.FAIL_WITH_REASON
      return send_response(parameters: [{ success: false }]) if @flags.FAIL_WITHOUT_REASON

      send_response(parameters: [{ success: true }])
    end

    def response_add
      send_response
    end

    def response_allterritories
      return send_response(parameters: []) if @flags.RETURN_NO_TERRITORIES

      territories = []
      Faker::Number.between(from: 100, to: 400).times do
        territories << {
          id: rand < 0.5 ? SecureRandom.uuid[0..4] : Faker::Lorem.sentence[0..20],
          territory_name: Faker::Lorem.sentence,
          owner_name: Faker::Name.name,
          owner_uid: Faker::Number.number(digits: 17).to_s
        }
      end

      send_response(parameters: territories)
    end

    # !sqf
    def response_exec
      message =
        if @data.parameters.target == "server"
          if @flags.WITH_RETURN
            "Executed on server successfully. Returned: ```true```"
          else
            "Executed code on server"
          end
        elsif @flags.ERROR # For some reason, I decided not to use the error system
          "Invalid target or target is not online"
        else
          "Executed code on target"
        end

      send_response(parameters: [{ message: message }])
    end

    def response_promote
      send_response
    end

    def response_remove
      send_response
    end
  end
end
