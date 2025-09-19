# frozen_string_literal: true

namespace :deploy do
  before :check, :update_env do
    on roles(:web) do |host|
      execute("~/scripts/setup_dependencies")
    end
  end
end
