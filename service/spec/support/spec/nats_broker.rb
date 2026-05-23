# frozen_string_literal: true

module Spec
  #
  # Spawns a real `nats-server` subprocess on a non-default port so integration
  # specs get an isolated broker instead of colliding with a dev instance. The
  # binary comes from the Nix dev shell; tests fail fast on missing PATH.
  #
  # @example
  #   broker = Spec::NatsBroker.new.start
  #   nats = NATS.connect(broker.url)
  #   # ...
  #   broker.stop
  #
  class NatsBroker
    DEFAULT_PORT = 4250
    READY_TIMEOUT = 5
    POLL_INTERVAL = 0.05

    attr_reader :port

    def initialize(port: DEFAULT_PORT)
      @port = port
      @pid = nil
    end

    def url
      "nats://127.0.0.1:#{@port}"
    end

    ##
    # Spawns the broker and waits until it accepts a TCP connection. Idempotent.
    #
    # @return [self]
    #
    def start
      return self if running?

      @pid = Process.spawn(
        "nats-server", "--port", @port.to_s, "--addr", "127.0.0.1",
        out: "/dev/null", err: "/dev/null"
      )

      wait_until_ready
      self
    end

    ##
    # Sends SIGTERM and reaps. Idempotent.
    #
    def stop
      return unless @pid

      Process.kill("TERM", @pid)
      Process.wait(@pid)
    rescue Errno::ESRCH, Errno::ECHILD
      # Already gone.
    ensure
      @pid = nil
    end

    ##
    # Stop + start, used by the reconnect spec to prove subscriptions re-establish.
    #
    def restart
      stop
      start
    end

    private

    def running?
      return false unless @pid

      Process.kill(0, @pid)
      true
    rescue Errno::ESRCH
      false
    end

    def wait_until_ready
      deadline = Time.now + READY_TIMEOUT
      loop do
        return if tcp_open?
        raise "nats-server on port #{@port} did not become ready within #{READY_TIMEOUT}s" if Time.now > deadline

        sleep POLL_INTERVAL
      end
    end

    def tcp_open?
      TCPSocket.new("127.0.0.1", @port).close
      true
    rescue Errno::ECONNREFUSED
      false
    end
  end
end
