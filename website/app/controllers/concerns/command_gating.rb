# frozen_string_literal: true

##
# Answers "may this user run that command here".
#
module CommandGating
  extend ActiveSupport::Concern

  included do
    helper_method :command_accessible?
  end

  private

  ##
  # The server a command runs against, for the surfaces that have one. A community-scoped surface leaves this nil and
  # gates on its community alone; a server controller defines its own and overrides this.
  #
  # @return [ESM::Server, nil]
  #
  def current_server
    nil
  end

  ##
  # Builds a CommandAccess check for command_name against the current user and whichever context this surface carries -
  # a server for the commands that target one, otherwise the community - and returns its permission verdict.
  #
  # @param command_name [String, Symbol] The name of the command
  #
  # @return [ESM::Command::Permission::Result] The verdict, exposing allowed? and the denial reason when not allowed
  #
  def command_verdict(command_name)
    ESM::CommandAccess.new(
      command_name:,
      user: current_user,
      community: current_community,
      server: current_server
    ).verdict
  end

  ##
  # Whether the current user is allowed to run command_name here.
  #
  # @param command_name [String, Symbol] The name of the command
  #
  # @return [Boolean] true when the verdict allows the command
  #
  def command_accessible?(command_name)
    command_verdict(command_name).allowed?
  end
end
