# frozen_string_literal: true

FactoryBot.define do
  factory :server_setting, class: "ESM::ServerSetting" do
    # server_id {}

    # Do not randomize otherwise it'll break the client
    # extdb_path { Faker::File.dir }
    # logging_path { Faker::File.dir }

    gambling_payout_base { Faker::Number.between(from: 1, to: 100) }
    gambling_modifier { Faker::Number.between(from: 1, to: 3) }
    gambling_payout_randomizer_min { 0 }
    gambling_payout_randomizer_mid { 0.5 }

    gambling_payout_randomizer_max do
      value = (rand + 0.75).round(3)
      (value > 1) ? 1 : value
    end

    gambling_win_percentage { Faker::Number.between(from: 1, to: 100) }
    logging_add_player_to_territory { true }
    logging_demote_player { true }
    logging_exec { false }
    logging_gamble { true }
    logging_modify_player { true }
    logging_pay_territory { true }
    logging_promote_player { true }
    logging_remove_player_from_territory { true }
    logging_reward_player { true }
    logging_transfer_poptabs { true }
    logging_upgrade_territory { true }
    max_payment_count { Faker::Number.number(digits: 1) }
    request_thread_type { "exile" }
    request_thread_tick { 0.1 }
    territory_payment_tax { Faker::Number.between(from: 1, to: 100) }
    territory_upgrade_tax { Faker::Number.between(from: 1, to: 100) }
    territory_price_per_object { Faker::Number.between(from: 1, to: 100) }
    territory_lifetime { Faker::Number.between(from: 7, to: 14) }
    server_restart_hour { Faker::Number.between(from: 1, to: 6) }
    server_restart_min { Faker::Number.between(from: 1, to: 60) }
  end
end
