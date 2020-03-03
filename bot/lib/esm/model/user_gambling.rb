# frozen_string_literal: true

module ESM
  class UserGambling < ApplicationRecord
    attribute :user_id, :integer
    attribute :server_id, :integer
    attribute :current_streak, :integer, default: 0
    attribute :total_wins, :integer, default: 0
    attribute :last_win_streak, :integer, default: 0
    attribute :total_poptabs_won, :integer, default: 0
    attribute :total_poptabs_loss, :integer, default: 0
    attribute :last_loss_streak, :integer, default: 0
    attribute :total_losses, :integer, default: 0
    attribute :last_action, :string, default: nil
    attribute :created_at, :datetime
    attribute :updated_at, :datetime

    belongs_to :user
    belongs_to :server
  end
end
