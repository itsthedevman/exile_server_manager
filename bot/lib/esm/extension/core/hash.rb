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

    Struct.new(*keys.map(&:to_sym)).new(*values.map { |value| recurse.call(value) })
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

    OpenStruct.new(**transform_values { |value| recurse.call(value) })
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

    ImmutableStruct.define(*keys.map(&:to_sym)).new(*values.map { |value| recurse.call(value) })
  end

  def join_map(join_with = "", &)
    filter_map(&).join(join_with)
  end
end
