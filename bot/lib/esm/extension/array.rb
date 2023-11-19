# frozen_string_literal: true

class Array
  def format(join_with: "", &block)
    filter_map(&block).join(join_with)
  end

  # Adds up all the sizes of every element inside the array
  def total_size
    reduce(0) do |total, i|
      size =
        case i
        when Array
          i.total_size
        when Integer
          i
        else
          i.size
        end

      total + size
    end
  end
end
