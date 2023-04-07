# frozen_string_literal: true

module ESM
  class Message
    include ESM::Callbacks

    #
    # Creates an instance of ESM::Message from JSON. See #to_h for the structure
    # @see #to_h
    #
    # @param json [String] The JSON to parse
    #
    # @return [Self]
    #
    def self.from_string(json)
      from_hash(json.to_h)
    end

    #
    # Creates a instance from a hash
    #
    # @param hash [Hash] The hash that contains the message contents
    #
    # @return [Self] The message
    #
    def self.from_hash(hash)
      hash = hash.deep_symbolize_keys

      message = event
      message = message.set_id(hash[:id]) if hash[:id].present?
      message = message.set_type(hash[:type]) if hash[:type].present?

      if hash[:data].present?
        message = message.set_data(hash.dig(:data, :type), hash.dig(:data, :content))
      end

      if hash[:metadata].present?
        message = message.set_metadata(hash.dig(:metadata, :type), hash.dig(:metadata, :content))
      end

      message = message.add_errors(hash[:errors]) if hash[:errors].present?
      message
    end

    def self.event
      new
    end

    def self.test
      new.set_type(:test)
    end

    def self.query
      new.set_type(:query)
    end

    def self.arma
      new.set_type(:arma)
    end

    attr_reader :id, :type, :attributes, :errors

    delegate :command, to: :attributes, allow_nil: true

    # All callbacks are provided with two arguments:
    #   incoming_message [ESM::Message, nil]  The incoming message from the client, if applicable.
    #   outgoing_message [ESM::Message, nil]  The outgoing message sent through the server, if applicable.
    #
    # Available callbacks:
    #   on_response
    #     - Called when a message receives a response to its contents.
    #   on_error
    #     - Called when a message experienced an error.
    #     - There is a default implementation called "on_error". To use it, call `message.add_callback(:on_error, :on_error)`
    register_callbacks :on_response, :on_error

    # The driver of communication between the bot, server, and client. Rust is strict so this has to be too.
    # Any data and metadata must be configured in config/mapping.yml and defined in esm_message -> data.rs / metadata.rs
    # They will automatically be sanitized according to their data type as configured in the mapping.
    # NOTE: Invalid data/metadata attributes will be dropped!
    def initialize
      @id = SecureRandom.uuid
      @type = "event"
      @data = Data.new
      @metadata = Data.new
      @errors = []
      @attributes = OpenStruct.new
      @delivered = false
      @mutex = Mutex.new
    end

    def set_id(id)
      @id = id
      self
    end

    def set_type(type)
      @type = type.to_s
      self
    end

    # The primary data for this message. It's the good stuff.
    def set_data(type = @type, content = nil)
      @data = Data.new(type, content)
      self
    end

    # Any extra data that may be needed. For most command messages, this will contain the user's discord and steam data.
    def set_metadata(type, content)
      @metadata = Data.new(type, content)
      self
    end

    # Each hash has the following attributes:
    #   type [Symbol, String] The type of error. Valid options are:
    #     code      # Uses the message to look up a predefined message in the locales
    #     message   # Treats the message like a string and sends it as is
    #   content [String] The content of this error.
    def add_errors(errors = [])
      return if !errors.respond_to?(:each)

      errors.each { |error| add_error(error[:type].to_s, error[:content]) }
      self
    end

    #
    # Adds the provided error to this message
    #
    # @param type [String] The error type. Valid types are: "code" and "message"
    # @param message [String] The message or code for this error
    #
    def add_error(type, content)
      return if type.nil? || content.nil?

      @errors << Error.new(type, content)
      self
    end

    def add_attribute(key, value)
      @attributes.send("#{key}=", value)
      self
    end

    def data_type
      @data.type
    end

    def data
      @data.content
    end

    def data_attributes(for_arma: false)
      @data.to_h(for_arma: for_arma)
    end

    def metadata_type
      @metadata.type
    end

    def metadata
      @metadata.content
    end

    def metadata_attributes(for_arma: false)
      @metadata.to_h(for_arma: for_arma)
    end

    #
    # Sets the user's ID, name, mention, and steam uid to the metadata for this message. Will also do the same for the target user if the command has one
    # This only applies to messages that have a command in their routing data
    #
    def apply_command_metadata
      metadata = Struct.new(:player, :target).new

      current_user = attributes.command&.current_user
      if current_user
        metadata.player = {
          steam_uid: current_user.steam_uid,
          discord_id: current_user.id.to_s,
          discord_name: current_user.username,
          discord_mention: current_user.mention
        }
      end

      target_user = attributes.command&.target_user
      if target_user
        target = {steam_uid: target_user.steam_uid}

        # Instances of TargetUser do not contain discord information
        if !target_user.is_a?(ESM::TargetUser)
          target.merge!(
            discord_id: target_user.id.to_s,
            discord_name: target_user.username,
            discord_mention: target_user.mention
          )
        end

        metadata.target = target
      end

      set_metadata(:command, metadata)
    end

    #
    # Converts the message to JSON
    #
    # @return [String] The message as JSON
    #
    def to_s
      to_h.to_json
    end

    #
    # Converts the message to a Hash
    #
    # @param for_arma [Boolean] Is this hash arma bound?
    #
    # @return [Hash] The message as a Hash. It has the following keys
    #   {
    #     id: The ID of this message as a UUID
    #     type: The context of this message
    #     data: {
    #       type: Describes the structure of content
    #       content: The actual "data"
    #     },
    #     metadata: {
    #       type: Describes the structure of content
    #       content: The actual "metadata"
    #     },
    #     errors: Any errors associated to this message
    #   }
    #
    def to_h(...)
      {
        id: id,
        type: type,
        data: data_attributes(...),
        metadata: metadata_attributes(...),
        errors: errors.map(&:to_h)
      }
    end

    #
    # Returns if there is any data on this message
    #
    # @return [Boolean]
    #
    def data?
      data.type && data.content
    end

    #
    # Returns if there is any metadata on this message
    #
    # @return [Boolean]
    #
    def errors?
      errors.any?
    end

    #
    # Used by MessageOverseer, this returns if the message has been delivered and is no longer needing to be watched
    #
    # @return [Boolean]
    #
    def delivered?
      @mutex.synchronize { @delivered }
    end

    #
    # Sets the delivered flag to true.
    # @see #delivered?
    #
    # @return [true]
    #
    def delivered
      @mutex.synchronize { @delivered = true }
    end

    #
    # Set's the message as synchronous
    # This sets the message's callbacks and forces `ESM::Connection::Server#send_message` to become blocking
    #
    def synchronous
      add_callback(:on_response) do |incoming_message|
        @mutex.synchronize { @incoming_message = incoming_message }
      end

      add_callback(:on_error) do |incoming_message|
        @mutex.synchronize { @incoming_message = incoming_message }
        @error = true
      end
    end

    #
    # Waits for a synchronous message to receive a response or timeout
    #
    # @return [ESM::Message] The incoming message containing the response or errors
    #
    def wait_for_response
      # Waits 2 minutes. This is a backup in case message overseer doesn't time it out
      counter = 0
      while !delivered? || counter >= 240
        sleep(0.1)
        counter += 1
      end

      # This should never raise. It's for emergencies
      raise ESM::Exception::MessageSyncTimeout if counter >= 240

      @mutex.synchronize { @incoming_message }
    end

    def inspect
      "#<ESM::Message #{JSON.pretty_generate(to_h)}>"
    end

    def on_response(incoming_message)
      run_callback(:on_response, incoming_message)

      # Runs after callbacks because of tests and such
      delivered
    end

    def on_error(incoming_message)
      if callback?(:on_error)
        run_callback(:on_error, incoming_message)
      else
        default_on_error(incoming_message)
      end

      delivered
    end

    private

    def default_on_error(incoming_message)
      errors = (self.errors || []) + (incoming_message&.errors || [])
      errors.map! { |e| e.to_s(self) }.uniq!

      if command.nil?
        error!(errors: errors)
      else
        command.current_cooldown&.reset!

        embed = ESM::Embed.build(:error, description: errors.join("\n"))
        command.reply(embed)
      end
    end
  end
end
