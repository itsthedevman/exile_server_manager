# frozen_string_literal: true

module Exceptions
  class NotFoundError < StandardError
  end

  class UnauthorizedError < StandardError
  end

  class BadRequestError < StandardError
  end

  class PayloadTooLargeError < StandardError
  end
end
