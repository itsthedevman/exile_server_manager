# frozen_string_literal: true

Dir[ESM_BOT_PATH.join("lib", "esm", "extension", "**", "*.rb")].sort.each { |extension| require extension }
Dir[ESM_BOT_PATH.join("lib", "esm", "discord", "extension", "**", "*.rb")].sort.each { |extension| require extension }
