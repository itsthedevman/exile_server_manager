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
      post_initialization: {send_ignore_message: true},
      me: {delay: 0..1},
      territories: {delay: 0..1},
      pay: {send_ignore_message: true, delay: 0..3},
      gamble: {send_ignore_message: true, delay: 0..3},
      setterritoryid: {delay: 0..1},
      add: {send_ignore_message: true, delay: 0..3},
      allterritories: {send_ignore_message: true, delay: 0..3},
      exec: {send_ignore_message: true, delay: 0..3},
      promote: {send_ignore_message: true, delay: 0..3},
      demote: {send_ignore_message: true, delay: 0..3},
      remove: {send_ignore_message: true, delay: 0..3},
      upgrade: {send_ignore_message: true, delay: 0..3},
      restore: {delay: 0..1},
      player: {send_ignore_message: true, delay: 0..3},
      reward: {send_ignore_message: true, delay: 0..3},
      info: {send_ignore_message: true, delay: 0..3},
      stuck: {delay: 0..1},
      reset: {delay: 0..1},
      logs: {delay: 0..1}
    }.freeze

    def response_server_success_command
      send_response
    end

    def response_server_error_command
      send_response(parameters: [{error: "oops"}])
    end

    def response_post_initialization
      @connected = true

      # The data the bot sends to the server to be stored
      @server_data = @data.parameters
      @server_id = @data.parameters.server_id
    end

    def response_me
      territories = {}

      Faker::Number.within(range: 1..3).times do
        territories[Faker::FunnyName.two_word_name] = Faker::Crypto.md5[0, 3]
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
          territories: territories.to_json
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
      return send_response(parameters: [{error: "Not enough poptabs!"}]) if @flags.NOT_ENOUGH_MONEY

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
      return send_response(parameters: [{success: false, reason: "Some reason"}]) if @flags.FAIL_WITH_REASON
      return send_response(parameters: [{success: false}]) if @flags.FAIL_WITHOUT_REASON

      send_response(parameters: [{success: true}])
    end

    def response_add
      send_response
    end

    def response_allterritories
      return send_response(parameters: []) if @flags.RETURN_NO_TERRITORIES

      territories = []
      Faker::Number.between(from: 75, to: 100).times do
        territories << {
          id: (rand < 0.5) ? SecureRandom.uuid[0..4] : Faker::Lorem.sentence[0..20],
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

      send_response(parameters: [{message: message}])
    end

    def response_promote
      send_response
    end

    def response_demote
      send_response
    end

    def response_remove
      send_response
    end

    def response_upgrade
      territory = TerritoryGenerator.generate

      send_response(
        parameters: [{
          cost: Faker::Number.between(from: 0, to: 10_000_000),
          level: territory[:level],
          range: territory[:radius],
          locker: Faker::Number.between(from: 0, to: 10_000_000)
        }]
      )
    end

    def response_restore
      send_response(
        parameters: [{
          success: @flags.SUCCESS
        }]
      )
    end

    def response_player
      # This handles kill and heal
      response = {type: @data.parameters.type}

      if %w[money locker respect].include?(@data.parameters.type)
        modified_amount = @data.parameters.value.to_i
        previous_amount = Faker::Number.between(from: 5000, to: 5_000_000)

        response = response.merge(
          modified_amount: modified_amount,
          previous_amount: previous_amount,
          new_amount: previous_amount + modified_amount
        )
      end

      send_response(parameters: [response])
    end

    def response_reward
      receipt = @server_data.reward_items.to_h
      receipt << ["Poptabs (Player)", @server_data.reward_player_poptabs] if @server_data.reward_player_poptabs.positive?
      receipt << ["Poptabs (Locker)", @server_data.reward_locker_poptabs] if @server_data.reward_locker_poptabs.positive?
      receipt << ["Respect", @server_data.reward_respect] if @server_data.reward_respect.positive?

      send_response(parameters: [{receipt: receipt}])
    end

    def response_info
      response = {}

      case @data.parameters.query
      when "territory_info"
        response = TerritoryGenerator.generate
      when "player_info"
        territories = {}

        if rand < 0.5
          Faker::Number.within(range: 1..3).times do
            territories[Faker::FunnyName.two_word_name] = Faker::Crypto.md5[0, 3]
          end
        end

        response = {
          locker: Faker::Number.within(range: 1..30_000),
          score: Faker::Number.within(range: 1..30_000),
          name: Faker::Internet.username,
          kills: Faker::Number.within(range: 1..100),
          deaths: Faker::Number.within(range: 1..100),
          territories: territories
        }

        if @flags.PLAYER_ALIVE
          response = response.merge(
            money: Faker::Number.within(range: 1..30_000),
            damage: Faker::Number.within(range: 0..0.9),
            hunger: Faker::Number.within(range: 1..100),
            thirst: Faker::Number.within(range: 1..100)
          )
        end
      end

      send_response(parameters: [response])
    end

    def response_stuck
      send_response(parameters: [{success: @flags.SUCCESS}])
    end

    def response_reset
      send_response(parameters: [{success: @flags.SUCCESS}])
    end

    # 0: The search parameters
    # 1..-1: The parsed logs
    #   date: <String> October 11 2020
    #   file_name (Exile_TradingLog.log): <Array>
    #     line: <Integer>
    #     entry: <String>
    #     date: <String 2020-10-11>
    def response_logs
      return send_response(parameters: [{}]) if @flags.NO_LOGS

      # The first object is not used, but is required
      logs = [{}]

      Faker::Number.between(from: 1, to: 4).times do
        logs << {
          :date => Faker::Date.in_date_period,
          "ExileTradingLog.log" => LogGenerator.generate_trading_log,
          "ExileTerritoryLog.log" => LogGenerator.generate_territory_log,
          "ExileDeathLog.log" => LogGenerator.generate_death_log
        }
      end

      send_response(parameters: logs)
    end
  end
end
