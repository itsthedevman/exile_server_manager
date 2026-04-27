# frozen_string_literal: true

module ESM
  class SteamAccount
    def token
      ENV["STEAM_TOKEN"]
    end
  end
end
