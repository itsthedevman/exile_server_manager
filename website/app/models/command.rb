# frozen_string_literal: true

class Command
  def self.all
    @all ||= ESM::CommandDetail.all
      .map { |c| Command.new(c) }
      .index_by(&:name)
      .symbolize_keys!
  end

  attr_reader :domain, :scope, :action
  attr_accessor :configuration

  attr_predicate :admin

  def initialize(command_details)
    @details = command_details

    parse_command_usage

    @admin = scope == :admin
  end

  def name
    @details.command_name
  end

  def type
    @details.command_type
  end

  def description
    @details.command_description
  end

  def arguments
    @details.command_arguments
  end

  def examples
    @details.command_examples
  end

  def category
    @details.command_category
  end

  def usage
    @details.command_usage
  end

  def attributes
    @details.command_attributes
  end

  def operation
    operation = ""
    operation += "#{scope} " if scope
    operation + action.to_s
  end

  def modifiable?
    attributes.any? { |_key, attrs| attrs["modifiable"] }
  end

  private

  def parse_command_usage
    parts = @details.command_usage.split(" ")

    # Split the command usage into parts using: /[domain] ?[scope] [action]
    @domain = parts.first.delete_prefix("/").to_sym
    @scope = nil
    @action = parts.third&.to_sym

    # If there is an action, we have a scope (/server admin find, /server my player)
    # Otherwise, there is no scope (/server gamble, /community servers)
    if @action.present?
      @scope = parts.second&.to_sym
    else
      @action = parts.second&.to_sym
    end

    # For commands like /help or /register
    if @scope.nil? && @action.nil?
      @action = @domain
      @domain = nil
    end
  end
end
