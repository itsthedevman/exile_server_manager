# frozen_string_literal: true

class TCPServer
  def blocker
    @blocker ||= Concurrent::AtomicBoolean.new
  end

  def block!
    blocker.make_true
  end

  def unblock!
    blocker.make_false
  end

  alias_method :p_accept_nonblock, :accept_nonblock

  def accept_nonblock(...)
    return if blocker.true?

    p_accept_nonblock(...)
  end
end
