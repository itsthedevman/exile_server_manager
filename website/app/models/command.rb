# frozen_string_literal: true

#
# Read-only view of a command for the website, sourced from the live command
# classes in core (admin + player commands only, matching what the dropped
# `command_details` cache used to hold).
#
class Command
  def self.all
    @all ||= ESM::Command.all
      .select { |command_class| ESM::Command::TYPES.include?(command_class.type) }
      .map { |command_class| new(command_class) }
      .index_by(&:name)
      .symbolize_keys!
  end

  attr_reader :domain, :scope, :action
  attr_accessor :configuration

  attr_predicate :admin

  def initialize(command_class)
    @details = command_class.to_details

    parse_command_usage

    @admin = scope == :admin
  end

  def name = @details[:name]
  def type = @details[:type]
  def description = @details[:description]
  def arguments = @details[:arguments]
  def examples = @details[:examples]
  def category = @details[:category]
  def usage = @details[:usage]
  def attributes = @details[:attributes]

  def operation
    operation = ""
    operation += "#{scope} " if scope
    operation + action.to_s
  end

  def modifiable?
    attributes.any? { |_key, attrs| attrs[:modifiable] }
  end

  private

  def parse_command_usage
    parts = usage.split(" ")

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
