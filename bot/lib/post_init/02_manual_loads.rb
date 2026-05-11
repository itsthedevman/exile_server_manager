# frozen_string_literal: true

require ESM.root.join("lib", "esm", "model", "application_record.rb")

Dir[ESM_CORE_PATH.join("lib", "**", "*.rb")].sort.each { |f| require f }

Dir[ESM.root.join("lib", "esm", "command", "base", "**", "*.rb")].sort.each { |f| require f }

require ESM.root.join("lib", "esm", "command.rb")
require ESM.root.join("lib", "esm", "command", "base.rb")
require ESM.root.join("lib", "esm", "model", "application_command.rb")
