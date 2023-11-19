# frozen_string_literal: true

class Hash
  def to_struct
    recurse = lambda do |value|
      case value
      when Hash
        value.to_struct
      when Array
        value.map(&recurse)
      else
        value
      end
    end

    struct = Struct.new(*keys)
    each.with_object(struct.new) do |(key, value), struct|
      struct.send("#{key}=", recurse.call(value))
    end
  end

  def to_ostruct
    recurse = lambda do |value|
      case value
      when Hash
        value.to_ostruct
      when Array
        value.map(&recurse)
      else
        value
      end
    end

    each.with_object(OpenStruct.new) do |(key, value), struct|
      struct.send("#{key}=", recurse.call(value))
    end
  end

  def to_istruct
    recurse = lambda do |input|
      case input
      when Hash
        input.to_istruct
      when Array
        input.map(&recurse)
      else
        input
      end
    end

    data_values = values.map { |value| recurse.call(value) }
    ImmutableStruct.define(*keys).new(*data_values)
  end

  def format(join_with: "", &block)
    map(&block).join(join_with)
  end
end
