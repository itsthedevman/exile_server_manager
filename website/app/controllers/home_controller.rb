# frozen_string_literal: true

class HomeController < ApplicationController
  def index
    command_count = ESM::CommandDetail.all.size
    years_alive = Date.today.year - 2018
    render locals: {command_count:, years_alive:}
  end
end
