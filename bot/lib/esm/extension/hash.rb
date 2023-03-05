# frozen_string_literal: true

class Hash
  def to_ostruct
    each.with_object(OpenStruct.new) do |(key, value), struct|
      recurse = lambda do |value|
        case value
        when Hash, ESM::Arma::HashMap
          value.to_ostruct
        when Array
          value.map(&recurse)
        else
          value
        end
      end

      struct.send("#{key}=", recurse.call(value))
    end
  end

  def format(join_with: "", &block)
    map(&block).join(join_with)
  end
end
