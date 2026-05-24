# frozen_string_literal: true

class DocsController < ApplicationController
  def commands
    commands = Command.all.values.sort_by(&:category)
    command_count = commands.size

    commands_by_domain = commands
      .group_by { |c| [c.domain, c.category] }
      .each_value { |commands| commands.sort_by!(&:operation) }
      .sort_by { |k, v| k.first || :"" } # Sort by domain, pushes the root commands to the top

    render locals: {commands_by_domain:, command_count:}
  end

  def getting_started
    command_count = Command.all.size

    render locals: {command_count:}
  end

  def player_setup
  end

  def server_setup
  end
end
