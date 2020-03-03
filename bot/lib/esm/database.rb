# frozen_string_literal: true

module ESM
  class Database
    def self.connect!
      path_to_database_yml = File.expand_path("./config/database.yml")
      ActiveRecord::Base.establish_connection(YAML.load_file(path_to_database_yml)[ESM.env])
    end

    def self.connected?
      ActiveRecord::Base.connected?
    end
  end
end
