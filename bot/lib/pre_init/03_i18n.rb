# frozen_string_literal: true

#
# Registers the bot's locale files with I18n. The reload is mandatory here:
# I18n caches its translations on first lookup, so any later lookup against
# an unreloaded backend would miss everything appended to `load_path` above.
#

I18n.load_path += Dir[ESM_BOT_PATH.join("config", "locales", "**", "*.yml")]
I18n.reload!
