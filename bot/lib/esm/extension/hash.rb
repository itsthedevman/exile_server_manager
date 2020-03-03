# frozen_string_literal: true

class Hash
  def to_ostruct
    self.to_json.to_ostruct
  end

  def format(join_with: "", &_block)
    self.map do |key, value|
      yield(key, value)
    end.join(join_with)
  end
end
