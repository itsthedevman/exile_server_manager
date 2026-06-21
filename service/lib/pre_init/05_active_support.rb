# frozen_string_literal: true

#
# ActiveSupport configuration that must be in place before any cache,
# inflector, or time operation runs.
#
#   * Cache format pinned to 7.1 to silence the deprecation warning and
#     lock in the current serialization format.
#   * Default time zone forced to UTC so timestamps never accidentally
#     pick up the host's local zone.
#   * Custom acronyms so identifiers like `esm_id` and `uid` classify
#     to `ESMID`/`UID` instead of `EsmId`/`Uid`.
#

ActiveSupport::Cache.format_version = 7.1

Time.zone_default = Time.find_zone!("UTC")

Loader.load_rails_extensions
