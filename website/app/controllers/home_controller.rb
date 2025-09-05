# frozen_string_literal: true

class HomeController < ApplicationController
  def index
    command_count = ESM::CommandDetail.all.size
    render locals: {command_count:}
  end
end
