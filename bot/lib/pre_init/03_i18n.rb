# frozen_string_literal: true

I18n.load_path += Dir[ESM_BOT_PATH.join("config", "locales", "**", "*.yml")]
I18n.reload!
