# frozen_string_literal: true

class String
  def steam_uid?
    ESM::Regex::STEAM_UID_ONLY.match(self)
  end

  def to_ostruct
    JSON.parse(self, object_class: OpenStruct)
  end

  def to_h
    JSON.parse(self, symbolize_names: true)
  end

  def to_poptab
    # NumberHelper contains instance methods, but you can't initialize a module. Create an anonymous object to store the methods
    helper = Object.new.extend(ActionView::Helpers::NumberHelper)
    value = helper.number_to_currency(self, unit: I18n.t(:poptabs), format: "%n %u", precision: 0)

    # 1 will convert to "1 poptabs", this makes it "1 poptab"
    if self == "1"
      value.gsub(I18n.t(:poptabs), I18n.t(:poptab))
    else
      value
    end
  end

  def to_readable
    helper = Object.new.extend(ActionView::Helpers::NumberHelper)
    helper.number_with_delimiter(self)
  end

  # Extending active support classify to allow leaving the s on the end
  def classify(keep_plural: false)
    if keep_plural
      self.sub(/.*\./, "").camelize
    else
      ActiveSupport::Inflector.classify(self)
    end
  end
end
