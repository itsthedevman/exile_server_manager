# frozen_string_literal: true

class Array
  def format(join_with: "", &_block)
    self.map do |i|
      yield(i)
    end.join(join_with)
  end

  # Adds up all the sizes of every element inside the array
  def total_size
    self.reduce(0) do |total, i|
      size =
        if i.is_a?(Array)
          i.total_size
        elsif i.is_a?(Integer)
          i
        else
          i.size
        end

      total + size
    end
  end
end
