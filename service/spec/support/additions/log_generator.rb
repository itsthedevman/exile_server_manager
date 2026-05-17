# frozen_string_literal: true

class LogGenerator
  TIMEZONES = ::ActiveSupport::TimeZone.all.map(&:name).freeze

  module Format
    DEATH = "%{player_name} %{reason}"

    # Trading formats
    TRADING_PURCHASE_ITEM = "PLAYER: ( %{player_uid} ) %{player_name} PURCHASED ITEM %{item} FOR %{number} POPTABS | PLAYER TOTAL MONEY: %{number}"
    TRADING_PURCHASE_VEHICLE = "PLAYER: ( %{player_uid} ) %{player_name} PURCHASED VEHICLE %{vehicle} FOR %{number} POPTABS | PLAYER TOTAL MONEY: %{number}"
    TRADING_PURCHASE_VEHICLE_SKIN = "PLAYER: ( %{player_uid} ) %{player_name} PURCHASED VEHICLE SKIN [%{skin}] (%{vehicle}) FOR %{number} POPTABS | PLAYER TOTAL MONEY: %{number}"
    TRADING_SOLD_CARGO = "PLAYER: ( %{player_uid} ) %{player_name} SOLD ITEM: %{vehicle} with Cargo [%{item}] FOR %{number} POPTABS AND %{number} RESPECT | PLAYER TOTAL MONEY: %{number}"
    TRADING_SOLD_ITEM = "PLAYER: ( %{player_uid} ) %{player_name} SOLD ITEM %{vehicle} FOR %{number} POPTABS AND %{number} RESPECT | PLAYER TOTAL MONEY: %{number}"

    TRADING = [TRADING_PURCHASE_ITEM, TRADING_PURCHASE_VEHICLE, TRADING_PURCHASE_VEHICLE_SKIN, TRADING_SOLD_CARGO, TRADING_SOLD_ITEM].freeze

    # Territory formats
    TERRITORY_PURCHASE = "PLAYER ( %{player_uid} ) %{player_name} PAID %{number} POP TABS TO PURCHASE A TERRITORY FLAG | PLAYER TOTAL POP TABS: %{number}"
    TERRITORY_PROTECT = "PLAYER ( %{player_uid} ) %{player_name} PAID %{number} POP TABS TO PROTECT THEIR OWN TERRITORY #%{number} | PLAYER TOTAL POP TABS: %{number}"
    TERRITORY_RANSOM = "PLAYER ( %{player_uid} ) %{player_name} PAID %{number} POP TABS FOR THE RANSOM OF TERRITORY #%{number} | PLAYER TOTAL POP TABS: %{number}"
    TERRITORY_UPGRADE = "PLAYER ( %{player_uid} ) %{player_name} PAID %{number} POP TABS TO UPGRADE TERRITORY #%{number} TO LEVEL %{number} | PLAYER TOTAL POP TABS: %{number}"
    TERRITORY_STOLE = "PLAYER ( %{player_uid} ) %{player_name} STOLE A LEVEL %{number} FLAG FROM TERRITORY #%{number}"

    TERRITORY = [TERRITORY_PURCHASE, TERRITORY_PROTECT, TERRITORY_RANSOM, TERRITORY_UPGRADE, TERRITORY_STOLE].freeze
  end

  def self.generate_trading_log
    # Set up the time
    starting_time = ::Faker::Time.backward(days: ::Faker::Number.between(from: 1, to: 14), period: :morning)
    starting_time = starting_time.in_time_zone(TIMEZONES.sample)
    end_time = starting_time.end_of_day

    output = []
    ::Faker::Number.between(from: 1, to: 250).times do
      current_format = Format::TRADING.sample
      current_time = ::Faker::Time.between(from: starting_time, to: end_time)

      formatted_entry = current_format % {
        player_uid: ::Faker::Number.number(digits: 17).to_s,
        player_name: ::Faker::Name.name,
        item: ::Faker::Commerce.product_name,
        number: ::Faker::Number.between(from: 1, to: 1_000_000),
        vehicle: ::Faker::Commerce.product_name,
        skin: ::Faker::Commerce.product_name
      }

      output << {
        date: current_time.to_date.strftime("%Y-%m-%d"),
        line: ::Faker::Number.between(from: 0, to: 25_000),
        entry: "#{log_prefix(current_time)} #{formatted_entry}"
      }
    end

    output
  end

  def self.generate_death_log
    # Set up the time
    starting_time = ::Faker::Time.backward(days: ::Faker::Number.between(from: 1, to: 14), period: :morning)
    starting_time = starting_time.in_time_zone(TIMEZONES.sample)
    end_time = starting_time.end_of_day

    output = []
    ::Faker::Number.between(from: 1, to: 250).times do
      current_time = ::Faker::Time.between(from: starting_time, to: end_time)

      formatted_entry = Format::DEATH % {
        player_name: ::Faker::Name.name,
        reason: ::Faker::Lorem.sentence
      }

      output << {
        date: current_time.to_date.strftime("%Y-%m-%d"),
        line: ::Faker::Number.between(from: 0, to: 25_000),
        entry: "#{log_prefix(current_time)} #{formatted_entry}"
      }
    end

    output
  end

  def self.generate_territory_log
    # Set up the time
    starting_time = ::Faker::Time.backward(days: ::Faker::Number.between(from: 1, to: 14), period: :morning)
    starting_time = starting_time.in_time_zone(TIMEZONES.sample)
    end_time = starting_time.end_of_day

    output = []
    ::Faker::Number.between(from: 1, to: 250).times do
      current_format = Format::TERRITORY.sample
      current_time = ::Faker::Time.between(from: starting_time, to: end_time)

      formatted_entry = current_format % {
        player_uid: ::Faker::Number.number(digits: 17).to_s,
        player_name: ::Faker::Name.name,
        number: ::Faker::Number.between(from: 1, to: 1_000_000)
      }

      output << {
        date: current_time.to_date.strftime("%Y-%m-%d"),
        line: ::Faker::Number.between(from: 0, to: 25_000),
        entry: "#{log_prefix(current_time)} #{formatted_entry}"
      }
    end

    output
  end

  private_class_method def self.log_prefix(date)
    "[#{date.strftime("%H:%M:%S:%6N %:z")}] [Thread #{::Faker::Number.between(from: 1000, to: 99_999)}]"
  end
end
