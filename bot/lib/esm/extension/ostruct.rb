# frozen_string_literal: true

class OpenStruct
  def blank?
    self.to_h.blank?
  end
end
