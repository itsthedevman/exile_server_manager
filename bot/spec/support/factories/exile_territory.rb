# frozen_string_literal: true

FactoryBot.define do
  factory :exile_territory, class: "ESM::ExileTerritory" do
    server_id {}
    name { "ExileTerritory - #{Faker::FunnyName.name}" }
    position_x { Faker::Number.between(from: 1, to: 1000) }
    position_y { Faker::Number.between(from: 1, to: 1000) }
    position_z { Faker::Number.between(from: 1, to: 20) }
    radius { Faker::Number.between(from: 1, to: 100) }
    level { Faker::Number.between(from: 1, to: 7) }
    flag_texture { ESM::ExileTerritory::FLAG_TEXTURES.sample }
    xm8_protectionmoney_notified { false }
    build_rights { [] }
    moderators { [] }
    last_paid_at { Time.now }

    trait :stolen do
      flag_stolen { true }
      flag_stolen_by_uid { ESM::Test.steam_uid }
      flag_stolen_at { Time.current }
    end

    before :create do |territory|
      next if ESM::ExileAccount.where(uid: territory.owner_uid).any?

      create(:exile_account, uid: territory.owner_uid)
    end
  end
end
