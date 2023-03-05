# frozen_string_literal: true

module ESM
  module Callbacks
    extend ActiveSupport::Concern

    included do
      class_attribute :__callbacks, default: {}
    end

    module ClassMethods
      def register_callbacks(*names)
        names.each { |name| __callbacks[name.to_sym] ||= [] }
      end

      def add_callback(name, method = nil, &block)
        __add_to_callback(__callbacks, name, method, &block)
        nil
      end

      def __add_to_callback(callbacks, name, method, &block)
        name = name.to_sym

        # Check to make sure the callback is registered
        if callbacks.keys.exclude?(name)
          return ESM.logger.warn("#{self.class}##{__method__}") { "Attempted to register invalid callback: #{name}" }
        end

        callbacks[name.to_sym] +=
          if block
            [block]
          elsif method.is_a?(Proc)
            [method]
          else
            [method.to_sym]
          end
      end
    end

    def add_callback(name, method = nil, &block)
      disconnect_callbacks!
      self.class.__add_to_callback(__callbacks, name, method, &block)
      nil
    end

    def run_callback(name, *arguments)
      callbacks = __callbacks[name.to_sym]
      return if callbacks.blank?

      callbacks.each do |callback|
        callback = method(callback) if callback.is_a?(Symbol)

        callback.call(*arguments)
      end
    end

    def remove_callback(callback_name, method_name)
      callbacks = __callbacks[callback_name.to_sym]
      return true if callbacks.blank?

      callbacks.reject! { |callback| callback == method_name.to_sym }
    end

    def callback?(name)
      __callbacks[name.to_sym].present?
    end

    private

    # __callbacks values are arrays so they're shared across the class and all of the instances
    # This redefines the values so each instance has it's own separate callbacks
    def disconnect_callbacks!
      return if @disconnected

      self.__callbacks = __callbacks.transform_values(&:dup)
      @disconnected = true
    end
  end
end
