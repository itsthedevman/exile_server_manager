# frozen_string_literal: true

class Integer
  delegate :to_poptab, :to_readable, to: :to_s
end
