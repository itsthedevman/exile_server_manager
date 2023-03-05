# frozen_string_literal: true

class String
  # NumberHelper contains instance methods, but you can't initialize a module. Create an anonymous object to store the methods
  NUMBER_HELPER = Object.new.extend(ActionView::Helpers::NumberHelper).freeze

  def steam_uid?
    ESM::Regex::STEAM_UID_ONLY.match?(self)
  end

  def to_ostruct
    ESM::JSON.parse(self, as_ostruct: true)
  end

  def to_h
    ESM::JSON.parse(self)
  end
  alias_method :to_a, :to_h

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

  # Extending active support classify to allow leaving the s on the end
  def classify(keep_plural: false)
    if keep_plural
      sub(/.*\./, "").camelize
    else
      ActiveSupport::Inflector.classify(self)
    end
  end
end
