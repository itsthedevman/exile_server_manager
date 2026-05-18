# frozen_string_literal: true

module ESM
  class SteamAccount
    def token
      Settings.steam_api_key
    end
  end
end
