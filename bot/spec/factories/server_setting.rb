# frozen_string_literal: true

FactoryBot.define do
  factory :server_setting, class: "ESM::ServerSetting" do
    # server_id {}
    extdb_path { Faker::File.dir }
    gambling_payout { Faker::Number.between(from: 1, to: 100) }
    gambling_modifier { Faker::Number.between(from: 1, to: 3) }
    gambling_randomizer_min { 0 }
    gambling_randomizer_mid { 0.5 }

    gambling_randomizer_max do
      value = (rand + 0.75).round(3)
      value > 1 ? 1 : value
    end

    gambling_win_chance { Faker::Number.between(from: 1, to: 100) }
    logging_path { Faker::File.dir }
    logging_add_player_to_territory { rand > 0.5 }
    logging_demote_player { rand > 0.5 }
    logging_exec { rand > 0.5 }
    logging_gamble { rand > 0.5 }
    logging_modify_player { rand > 0.5 }
    logging_pay_territory { rand > 0.5 }
    logging_promote_player { rand > 0.5 }
    logging_remove_player_from_territory { rand > 0.5 }
    logging_reward { rand > 0.5 }
    logging_transfer { rand > 0.5 }
    logging_upgrade_territory { rand > 0.5 }
    max_payment_count { Faker::Number.number(digits: 1) }
    request_thread_type { rand > 0.5 ? "exile" : "arma" }
    request_thread_tick { 0.1 }
    territory_payment_tax { Faker::Number.between(from: 1, to: 100) }
    territory_upgrade_tax { Faker::Number.between(from: 1, to: 100) }
    territory_price_per_object { Faker::Number.between(from: 1, to: 100) }
    territory_lifetime { Faker::Number.between(from: 7, to: 14) }
    server_restart_hour { Faker::Number.between(from: 1, to: 6) }
    server_restart_min { Faker::Number.between(from: 1, to: 60) }
  end
end
