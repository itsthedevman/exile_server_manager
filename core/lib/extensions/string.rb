# frozen_string_literal: true

class String
  NUMBER_HELPER = ActiveSupport::NumberHelper

  def steam_uid?
    ESM::Regex::STEAM_UID_ONLY.match?(self)
  end

  def discord_id?
    ESM::Regex::DISCORD_ID_ONLY.match?(self)
  end

  def to_poptab
    # Convert from Scientific notation.
    # Arma automatically converts to scientific notation if the value is greater than 2mil
    value = "%f" % self
    value = NUMBER_HELPER.number_to_currency(value, unit: I18n.t(:poptabs), format: "%n %u", precision: 0)

    # 1 will convert to "1 poptabs", this makes it "1 poptab"
    if self == "1"
      value.gsub(I18n.t(:poptabs), I18n.t(:poptab))
    else
      value
    end
  end

  def to_readable(precision: 0)
    NUMBER_HELPER.number_to_currency("%f" % self, format: "%n", precision: precision)
  end

  def to_delimited
    NUMBER_HELPER.number_to_delimited(self)
  end

  # Extending active support classify to allow leaving the s on the end
  def classify(keep_plural: false)
    if keep_plural
      sub(/.*\./, "").camelize
    else
      ActiveSupport::Inflector.classify(self)
    end
  end

  alias_method :to_h, :parse_json

  def to_deep_h
    recursive_convert = lambda do |object|
      case object
      when Array
        object.map { |v| recursive_convert.call(v) }
      when String
        parsed = object.parse_json

        # If it parsed successfully as JSON, recursively convert it
        if parsed.is_a?(Array) || parsed.is_a?(Hash)
          recursive_convert.call(parsed)
        else
          object
        end
      when Hash
        object.transform_values { |v| recursive_convert.call(v) }
      else
        object
      end
    end

    result = self.parse_json
    return if result.nil?

    recursive_convert.call(result)
  end
end
