# frozen_string_literal: true

module ESM
  class Database
    def self.connect!
      ActiveRecord::Base.configurations = config
      ActiveRecord::Base.establish_connection(ESM.env.to_sym)
    end

    def self.connected?
      ActiveRecord::Base.connected?
    end

    def self.config
      @config ||= YAML.safe_load(
        ERB.new(
          File.read(ESM.root.join("config", "database.yml"))
        ).result,
        aliases: true
      )
    end
  end
end
