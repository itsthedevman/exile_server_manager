# frozen_string_literal: true

module ESM
  class SteamAccount
    def summary
      {
        steam_id: @steam_uid,
        community_visibility_state: 3,
        profile_state: 3,
        persona_name: "Test user",
        last_logoff: "",
        comment_permission: "",
        profile_url: "",
        avatar: "",
        avatar_medium: "",
        avatar_full: "",
        persona_state: 3,
        primary_clan_id: -1,
        time_created: -1,
        persona_state_flags: 3
      }.to_istruct
    end
  end
end
