# frozen_string_literal: true

class Array
  def format(join_with: "", &_block)
    self.map do |i|
      yield(i)
    end.join(join_with)
  end

  # Adds up all the sizes of every element inside the array
  def total_size
    self.reduce(0) { |total, i| total + i.size }
  end
end
