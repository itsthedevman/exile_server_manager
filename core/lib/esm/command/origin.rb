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
      ##
      # The user who invoked the command.
      #
      # @abstract
      #
      # @return [ESM::User]
      #
      # @raise [NotImplementedError] if the adapter does not implement this method
      #
      def current_user
        raise NotImplementedError
      end

      ##
      # The community context in which the command was invoked, or nil when the invocation
      # has no community scope (e.g. a direct-message origin).
      #
      # @abstract
      #
      # @return [ESM::Community, nil]
      #
      # @raise [NotImplementedError] if the adapter does not implement this method
      #
      def current_community
        raise NotImplementedError
      end

      ##
      # The channel through which the command was received, or nil for origins that have
      # no channel concept (e.g. website RPCs).
      #
      # @abstract
      #
      # @return [Object, nil] a medium-specific channel object, or nil
      #
      # @raise [NotImplementedError] if the adapter does not implement this method
      #
      def current_channel
        raise NotImplementedError
      end

      ##
      # Delivers a reply back to the invoking user.
      #
      # @abstract Adapters serialize and route content for their medium.
      #
      # @param content [String, ESM::Embed] the reply body
      #
      # @raise [NotImplementedError] if the adapter does not implement this method
      #
      def reply(content)
        raise NotImplementedError
      end

      ##
      # Identifying context merged into error-warning payloads so logs carry medium-specific
      # metadata (channel id, request id, etc.) without exposing adapter types to core error
      # handling. Adapters override this to inject their own fields.
      #
      # @return [Hash]
      #
      def log_context
        {}
      end

      ##
      # Whether the command was invoked from the website.
      #
      # @return [Boolean] true when this origin's source is the website
      #
      def from_website?
        @source == :website
      end

      ##
      # Whether the command was invoked from Discord.
      #
      # @return [Boolean] true when this origin's source is Discord
      #
      def from_discord?
        @source == :discord
      end
    end
  end
end
