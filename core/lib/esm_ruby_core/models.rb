# frozen_string_literal: true

Dir[File.join(File.expand_path("..", __dir__), "esm/**/*.rb")].sort.each { |path| require path }
