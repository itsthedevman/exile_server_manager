# frozen_string_literal: true

module Spec
  #
  # Real Discord ids for guilds this bot is actually a member of, for the live run.
  #
  # `ESM::Community#discord_server` is `ESM.discord_bot.server(guild_id)`, a cache lookup, so an invented guild id
  # resolves to nil and every Discord-reading handler answers nil for a reason that has nothing to do with whether
  # it works. Telling those two apart is the entire point of the live tier, and real ids are the only way to do it.
  #
  # The ids never enter this repository. `spec/.test_data.yml` is gitignored, and is expected to be a symlink to
  # wherever they are actually kept.
  #
  class TestData
    PATH = ESM.root.join("spec", ".test_data.yml")

    class << self
      # The guild the live specs run against. It has to be one whose owner is known, because `owner_discord_id` is
      # the only identity that is an admin there by definition rather than by configuration.
      def guild_id = primary.fetch(:server_id).to_s

      def owner_discord_id = primary.fetch(:owner_id).to_s

      # A member who holds a role but does not own the guild. The permission axis needs both ends of that.
      def role_user = primary.fetch(:role_users).first

      def member_discord_ids = primary.fetch(:users).map(&:to_s)

      def logging_channel_id = primary.fetch(:logging_channel_id).to_s

      def channel_ids = primary.fetch(:channels).map(&:to_s)

      def everyone_role_id = primary.fetch(:everyone_role).to_s

      # A second guild, for anything that has to prove it is reading the right one rather than the only one.
      def secondary = section(:secondary)

      def primary = section(:primary)

      # A guild id in the right format that no bot is a member of. Nothing Discord generates will collide with it,
      # so a handler answering nil for this one is answering nil because the guild did not resolve.
      def unknown_guild_id = "910000000000000002"

      def steam_uids = data.fetch(:steam_uids)

      private

      def section(name) = data.fetch(name)

      # Read once per process rather than per example. Nothing here changes while the suite runs, and the failure
      # when the file is absent should name the fix rather than surfacing later as a nil guild id.
      def data
        @data ||=
          begin
            unless PATH.exist?
              raise "No live test data at #{PATH}. Symlink it there. It needs `primary.server_id` set to a guild " \
                    "this bot is a member of, `primary.owner_id` set to that guild's owner, and a `role_users` " \
                    "entry naming a member and a non-administrator role they hold."
            end

            YAML.safe_load_file(PATH, symbolize_names: true)
          end
      end
    end
  end
end
