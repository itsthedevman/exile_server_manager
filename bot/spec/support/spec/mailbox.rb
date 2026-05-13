# frozen_string_literal: true

module Spec
  #
  # Thread-safe queue with a predicate-based wait primitive. Shared base for
  # {Spec::Inbox} (consume-on-read; queues replies for the bot to receive) and
  # {Spec::Outbox} (peek-on-read; audit log of what the bot has sent out).
  #
  class Mailbox
    POLL_INTERVAL = 0.05
    DEFAULT_TIMEOUT = 10

    def initialize
      @mutex = Mutex.new
      @items = []
    end

    def push(item)
      @mutex.synchronize { @items << item }
      item
    end

    def clear
      @mutex.synchronize { @items.clear }
    end

    def size
      @mutex.synchronize { @items.size }
    end

    def empty?
      size.zero?
    end

    def to_a
      @mutex.synchronize { @items.dup }
    end

    #
    # Block until an item matches `predicate` or the deadline elapses.
    #
    # @param timeout [Numeric] seconds to wait
    # @param consume [Boolean] when true the matched item is removed from the
    #   queue (request/response semantics); when false it is left in place
    #   (audit-log semantics)
    #
    # @yield [item] called inside the mutex; return truthy to match
    #
    # @return [Object, nil] the matched item, or nil on timeout
    #
    def wait(timeout: DEFAULT_TIMEOUT, consume: false, &predicate)
      deadline = Time.now + (timeout || DEFAULT_TIMEOUT)

      loop do
        match = @mutex.synchronize do
          if consume
            index = @items.find_index(&predicate)
            @items.delete_at(index) if index
          else
            @items.find(&predicate)
          end
        end

        return match if match
        return nil if Time.now >= deadline

        sleep POLL_INTERVAL
      end
    end
  end
end
