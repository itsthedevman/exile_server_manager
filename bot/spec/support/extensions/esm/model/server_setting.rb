# frozen_string_literal: true

module ESM
  class ServerSetting
    after_save :update_arma

    private

    MAPPING = {
      gambling_locker_limit_enabled: "ESM_Gambling_LockerLimitEnabled",
      gambling_modifier: "ESM_Gambling_Modifier",
      gambling_payout_base: "ESM_Gambling_PayoutBase",
      gambling_payout_randomizer_max: "ESM_Gambling_PayoutRandomizerMax",
      gambling_payout_randomizer_mid: "ESM_Gambling_PayoutRandomizerMid",
      gambling_payout_randomizer_min: "ESM_Gambling_PayoutRandomizerMin",
      gambling_win_percentage: "ESM_Gambling_WinPercentage",
      logging_add_player_to_territory: "ESM_Logging_CommandAdd",
      logging_demote_player: "ESM_Logging_CommandDemote",
      logging_exec: "ESM_Logging_CommandSqf",
      logging_gamble: "ESM_Logging_CommandGamble",
      logging_modify_player: "ESM_Logging_CommandPlayer",
      logging_pay_territory: "ESM_Logging_CommandPay",
      logging_promote_player: "ESM_Logging_CommandPromote",
      logging_remove_player_from_territory: "ESM_Logging_CommandRemove",
      logging_reward_player: "ESM_Logging_CommandReward",
      logging_transfer_poptabs: "ESM_Logging_CommandTransfer",
      logging_upgrade_territory: "ESM_Logging_CommandUpgrade",

      # These two differ from their A3 counterparts.
      # Years ago I renamed them to be "taxes_territory_payment" and "taxes_territory_upgrade"
      territory_payment_tax: "ESM_Taxes_TerritoryPayment",
      territory_upgrade_tax: "ESM_Taxes_TerritoryUpgrade"
    }.stringify_keys.freeze

    def update_arma
      return unless server.v2? && server.connected?

      changed_items = previous_changes.slice(*MAPPING.keys)
      return if changed_items.blank?

      sqf = changed_items.map_join(";") do |key, (_, value)|
        arma_variable = MAPPING[key]
        if arma_variable.nil?
          warn!(
            "ServerSetting attribute #{key.quoted} was updated but does not have a MAPPING entry"
          )

          next
        end

        value /= 100.0 if %w[territory_upgrade_tax territory_payment_tax].include?(key)

        "missionNamespace setVariable [#{arma_variable.to_json}, #{value.to_json}]"
      end

      if changed_items.key?("gambling_payout_base")
        sqf += ";missionNamespace setVariable [\"ESM_Gambling_PayoutModifier\", ESM_Gambling_PayoutBase / 100]"
      end

      if changed_items.key?("gambling_win_percentage")
        sqf += ";missionNamespace setVariable [\"ESM_Gambling_WinPercentage\", ESM_Gambling_WinPercentage / 100]"
      end

      changes_gambling_randomizer = %w[
        gambling_payout_randomizer_max
        gambling_payout_randomizer_mid
        gambling_payout_randomizer_min
      ]

      if changed_items.keys.intersect?(changes_gambling_randomizer)
        sqf += ";missionNamespace setVariable [\"ESM_Gambling_PayoutRandomizer\", [ESM_Gambling_PayoutRandomizerMin,ESM_Gambling_PayoutRandomizerMid,ESM_Gambling_PayoutRandomizerMax]]"
      end

      server.execute_sqf!(sqf)
    end
  end
end
