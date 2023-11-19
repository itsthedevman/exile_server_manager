# frozen_string_literal: true

namespace :server do
  task set_server_visibility: :environment do
    ESM::Server.all.update_all(server_visibility: :public)
  end
end
