# frozen_string_literal: true

module ESM
  class Database
    def self.connect!
      ActiveRecord::Base.establish_connection(config)
    end

    def self.connected?
      ActiveRecord::Base.connected?
    end

    def self.config
      @config ||= YAML.safe_load(ERB.new(File.read(File.expand_path("./config/database.yml"))).result, aliases: true)[ESM.env]
    end
  end
end
