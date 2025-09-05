# frozen_string_literal: true

class DocsController < ApplicationController
  def commands
    commands = ESM::CommandDetail.all.order(command_category: :asc).map { |c| Command.new(c) }
    command_count = commands.size

    commands_by_domain = commands
      .group_by { |c| [c.domain, c.category] }
      .each_value { |commands| commands.sort_by!(&:operation) }
      .sort_by { |k, v| k.first || :"" } # Sort by domain, pushes the root commands to the top

    render locals: {commands_by_domain:, command_count:}
  end

  def getting_started
    command_count = ESM::CommandDetail.all.size

    render locals: {command_count:}
  end

  def player_setup
  end

  def server_setup
  end
end
