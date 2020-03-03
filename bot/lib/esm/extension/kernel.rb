# frozen_string_literal: true

module Kernel
  # Expose I18n t and l to everything!
  def l(*args)
    I18n.l(*args)
  end

  def t(*args)
    I18n.t(*args)
  end
end
