# frozen_string_literal: true

module ESM
  class UserGambleStat < ApplicationRecord
    # =============================================================================
    # INITIALIZE
    # =============================================================================

    # =============================================================================
    # DATA STRUCTURE
    # =============================================================================

    attribute :user_id, :integer
    attribute :server_id, :integer
    attribute :current_streak, :integer, default: 0
    attribute :total_wins, :integer, default: 0
    attribute :longest_win_streak, :integer, default: 0
    attribute :total_poptabs_won, :integer, limit: 8, default: 0
    attribute :total_poptabs_loss, :integer, limit: 8, default: 0
    attribute :longest_loss_streak, :integer, default: 0
    attribute :total_losses, :integer, default: 0
    attribute :last_action, :string, default: nil
    attribute :created_at, :datetime
    attribute :updated_at, :datetime

    # =============================================================================
    # ASSOCIATIONS
    # =============================================================================

    belongs_to :user
    belongs_to :server

    # =============================================================================
    # VALIDATIONS
    # =============================================================================

    # =============================================================================
    # CALLBACKS
    # =============================================================================

    # =============================================================================
    # SCOPES
    # =============================================================================

    # =============================================================================
    # CLASS METHODS
    # =============================================================================

    # =============================================================================
    # INSTANCE METHODS
    # =============================================================================
  end
end
