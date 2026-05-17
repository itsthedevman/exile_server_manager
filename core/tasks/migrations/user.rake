# frozen_string_literal: true

namespace :user do
  task create_user_default: :environment do
    user_ids = ESM::User.all.pluck(:id)
    user_ids.each do |user_id|
      ESM::UserDefault.where(user_id: user_id).first_or_create
    end
  end
end
