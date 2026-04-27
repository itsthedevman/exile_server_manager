# frozen_string_literal: true

class Integer
  delegate :to_poptab, :to_readable, to: :to_s

  def to_delimitated_s(...)
    ActiveSupport::NumberHelper.number_to_delimited(self, ...)
  end
end
