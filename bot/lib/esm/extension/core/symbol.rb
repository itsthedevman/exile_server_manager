# frozen_string_literal: true

class Symbol
  alias_method :quoted, :to_json
end
