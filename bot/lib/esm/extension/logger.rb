# frozen_string_literal: true

class Logger
  send :remove_const, "SEV_LABEL"

  SEV_LABEL = {
    -1 => "TRACE",
    0 => "DEBUG",
    1 => "INFO",
    2 => "WARN",
    3 => "ERROR",
    4 => "FATAL",
    5 => "ANY"
  }.freeze

  module Severity
    TRACE = -1
  end

  def trace(progname = nil, &block)
    add(TRACE, nil, progname, &block)
  end

  def trace?
    @level <= TRACE
  end
end
