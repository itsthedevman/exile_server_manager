# frozen_string_literal: true

module ESM
  class UserGambleStat < ApplicationRecord
    # =============================================================================
    # INITIALIZE
    # =============================================================================

    WON_ACTION = "won"
    LOSS_ACTION = "loss"

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

    #
    # Records the outcome of a single gamble, updating the win/loss totals, poptab tallies, and the
    # current/longest streaks. Switching between a win and a loss resets the current streak to 1.
    #
    # @param win [Boolean] whether this gamble was won
    # @param amount_changed [Integer] the poptabs won (on a win) or lost (on a loss)
    #
    # @return [Boolean] true once the stats are persisted
    #
    def record!(win:, amount_changed:)
      # Ensure the streak is reset when switching between won/loss
      current_streak =
        if last_action == (win ? WON_ACTION : LOSS_ACTION)
          self.current_streak + 1
        else
          1
        end

      if win
        # Determine if we've broken our previous streak
        longest_win_streak =
          if current_streak > self.longest_win_streak
            current_streak
          else
            self.longest_win_streak
          end

        # Update the stats
        update!(
          total_wins: total_wins + 1,
          total_poptabs_won: total_poptabs_won + amount_changed,
          current_streak:,
          longest_win_streak:,
          last_action: WON_ACTION
        )
      else
        # Determine if we've broken our previous streak
        longest_loss_streak =
          if current_streak > self.longest_loss_streak
            current_streak
          else
            self.longest_loss_streak
          end

        # Update the stats
        update!(
          total_losses: total_losses + 1,
          total_poptabs_loss: total_poptabs_loss + amount_changed,
          current_streak:,
          longest_loss_streak:,
          last_action: LOSS_ACTION
        )
      end
    end
  end
end
