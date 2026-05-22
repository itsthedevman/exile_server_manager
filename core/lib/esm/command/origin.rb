# frozen_string_literal: true

module ESM
  module Command
    ##
    # Abstract surface for everything a {Command::Base} needs to interact with whoever
    # invoked it: the calling user, the community/channel context, and the reply path.
    # Concrete adapters wrap a specific medium (Discord events, website RPCs).
    #
    # The command lifecycle stays origin-agnostic; medium-specific bodies live in the
    # adapter that implements this interface.
    #
    class Origin
      def current_user
        raise NotImplementedError
      end

      def current_community
        raise NotImplementedError
      end

      def current_channel
        raise NotImplementedError
      end

      # Delivers a reply back to whoever invoked the command. Accepts a String or
      # {ESM::Embed}; concrete adapters decide how to serialize and route it.
      def reply(content)
        raise NotImplementedError
      end

      # Hash merged into {Helpers#raise_error!}'s warn payload so logs carry the
      # origin's identifying context (channel id, request id, etc.) without leaking
      # medium-specific types into core.
      def log_context
        {}
      end
    end
  end
end
