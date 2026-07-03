# frozen_string_literal: true

module Servers
  class GamblingController < AuthenticatedController
    VALID_AMOUNT = /\A(\d+|half|all)\z/i

    # Dev-only stub
    def create
      render :create, locals: {
        current_server:,
        gamble_stat:,
        result: placeholder_result
      }
    end

    private

    def current_server
      @current_server ||= ESM::Server.find_by_public_id(params[:server_id])
    end

    def gamble_stat
      @gamble_stat ||= ESM::UserGambleStat.find_or_initialize_by(
        server_id: current_server.id,
        user_id: current_user.id
      )
    end

    def submitted_amount
      @submitted_amount ||= params[:amount].to_s.strip
    end

    # Dev-only stub
    def placeholder_result
      return result_struct(error: "Enter an amount to gamble, or pick Half or All.") unless submitted_amount.match?(VALID_AMOUNT)

      won = [true, false].sample
      wager = wager_preview

      result_struct(
        win: won,
        amount: wager,
        locker_after: won ? 1_000_000 + wager : [1_000_000 - wager, 0].max,
        streak: rand(1..6)
      )
    end

    # Dev-only stub
    def wager_preview
      submitted_amount.match?(/\A\d+\z/) ? submitted_amount.to_i : 50_000
    end

    def result_struct(win: nil, amount: 0, locker_after: 0, streak: 0, error: nil)
      {win:, amount:, locker_after:, streak:, error:}.to_istruct
    end
  end
end
