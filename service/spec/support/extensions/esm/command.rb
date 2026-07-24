# frozen_string_literal: true

module ESM
  module Command
    def self.clear
      @all = []
      @by_type = []
      @by_namespace = {}
      @configurations = nil
    end
  end
end
