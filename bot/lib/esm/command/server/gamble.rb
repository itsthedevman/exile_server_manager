# frozen_string_literal: true

module ESM
  module Command
    module Server
      class Gamble < ApplicationCommand
        #################################
        #
        # Arguments (required first, then order matters)
        #

        # Required: Needed by command
        argument :amount, checked_against: /(?!-\d+$)\d+|half|all|stats/

        # See Argument::TEMPLATES[:server_id]
        argument :server_id, display_name: :on

        #
        # Configuration
        #

        command_type :player

        # Skipped because of amount:stats argument
        skip_action :connected_server

        #################################

        def on_execute
          return reply(send_stats) if arguments.amount.nil? || arguments.amount == "stats"

          check_for_connected_server!
          check_for_bad_amount!

          deliver!(
            function_name: "gamble",
            uid: current_user.steam_uid,
            amount: arguments.amount,
            id: current_user.discord_id,
            name: current_user.username
          )
        end

        def on_response
          update_stats
          send_results
        end

        private

        def check_for_bad_amount!
          return if %w[half all].include?(arguments.amount)

          raise_error!(:bad_amount, user: current_user.mention) if arguments.amount.to_i <= 0
        end

        def gamble_stat
          @gamble_stat ||= ESM::UserGambleStat.where(server_id: target_server.id, user_id: current_user.id).first_or_create
        end

        def send_stats
          # Don't set a cooldown
          skip_action(:cooldown)

          ESM::Embed.build do |e|
            e.title = I18n.t("commands.gamble.stats.title", server_id: target_server.server_id)
            add_current_stats(e)
            add_server_stats(e)
          end
        end

        def add_current_stats(embed)
          embed.add_field(value: I18n.t("commands.gamble.stats.user_stats", user: current_user.mention))
          embed.add_field(name: I18n.t("commands.gamble.stats.total_wins"), value: gamble_stat.total_wins, inline: true)
          embed.add_field(name: I18n.t("commands.gamble.stats.total_losses"), value: gamble_stat.total_losses, inline: true)
          embed.add_field(name: I18n.t("commands.gamble.stats.total_poptabs_won"), value: gamble_stat.total_poptabs_won, inline: true)
          embed.add_field(name: I18n.t("commands.gamble.stats.total_poptabs_lost"), value: gamble_stat.total_poptabs_loss, inline: true)
          embed.add_field(name: I18n.t("commands.gamble.stats.current_streak"), value: gamble_stat.current_streak, inline: true)
          embed.add_field(name: I18n.t("commands.gamble.stats.longest_win_streak"), value: gamble_stat.longest_win_streak, inline: true)
          embed.add_field(name: I18n.t("commands.gamble.stats.longest_losing_streak"), value: gamble_stat.longest_loss_streak, inline: true)
        end

        def add_server_stats(embed)
          embed.add_field(value: I18n.t("commands.gamble.stats.server_stats"))

          longest_current_streak_stat = target_server.longest_current_streak
          user_name = longest_current_streak_stat.user.discord_user.distinct
          embed.add_field(
            name: I18n.t("commands.gamble.stats.longest_current_streak"),
            value: I18n.t("commands.gamble.stats.user_with", user: user_name, value: longest_current_streak_stat.current_streak)
          )

          longest_win_streak_stat = target_server.longest_win_streak
          user_name = longest_win_streak_stat.user.discord_user.distinct
          embed.add_field(
            name: I18n.t("commands.gamble.stats.longest_win_streak"),
            value: I18n.t("commands.gamble.stats.user_with", user: user_name, value: longest_win_streak_stat.longest_win_streak)
          )

          longest_losing_streak_stat = target_server.longest_losing_streak
          user_name = longest_losing_streak_stat.user.discord_user.distinct
          embed.add_field(
            name: I18n.t("commands.gamble.stats.longest_losing_streak"),
            value: I18n.t("commands.gamble.stats.user_with", user: user_name, value: longest_losing_streak_stat.longest_loss_streak)
          )

          most_poptabs_won_stat = target_server.most_poptabs_won
          user_name = most_poptabs_won_stat.user.discord_user.distinct
          embed.add_field(
            name: I18n.t("commands.gamble.stats.most_poptabs_won"),
            value: I18n.t("commands.gamble.stats.user_with", user: user_name, value: most_poptabs_won_stat.total_poptabs_won.to_poptab)
          )

          most_poptabs_lost_stat = target_server.most_poptabs_lost
          user_name = most_poptabs_lost_stat.user.discord_user.distinct
          embed.add_field(
            name: I18n.t("commands.gamble.stats.most_poptabs_lost"),
            value: I18n.t("commands.gamble.stats.user_with", user: user_name, value: most_poptabs_lost_stat.total_poptabs_loss.to_poptab)
          )
        end

        def update_stats
          # Ensure the streak is reset when switching between won/lost
          current_streak =
            if gamble_stat.last_action == @response.type
              gamble_stat.current_streak + 1
            else
              1
            end

          case @response.type
          when "won"
            # Determine if we've broken our previous streak
            longest_win_streak =
              if current_streak > gamble_stat.longest_win_streak
                current_streak
              else
                gamble_stat.longest_win_streak
              end

            # Update the stats
            gamble_stat.update(
              total_wins: gamble_stat.total_wins + 1,
              total_poptabs_won: gamble_stat.total_poptabs_won + @response.amount.to_i,
              current_streak: current_streak,
              longest_win_streak: longest_win_streak,
              last_action: @response.type
            )
          when "loss"
            # Determine if we've broken our previous streak
            longest_loss_streak =
              if current_streak > gamble_stat.longest_loss_streak
                current_streak
              else
                gamble_stat.longest_loss_streak
              end

            # Update the stats
            gamble_stat.update(
              total_losses: gamble_stat.total_losses + 1,
              total_poptabs_loss: gamble_stat.total_poptabs_loss + @response.amount.to_i,
              current_streak: current_streak,
              longest_loss_streak: longest_loss_streak,
              last_action: @response.type
            )
          end
        end

        def send_results
          embed = ESM::Notification.build_random(
            community_id: target_community.id,
            type: @response.type,
            category: "gambling",
            serverid: target_server.server_id,
            servername: target_server.server_name,
            communityid: target_community.community_id,
            username: current_user.username,
            usertag: current_user.mention,
            amountchanged: @response.amount,
            amountgambled: arguments.amount,
            lockerbefore: @response.locker_before,
            lockerafter: @response.locker_after
          )

          embed.footer = "Current Streak: #{gamble_stat.current_streak}"
          reply(embed)
        end
      end
    end
  end
end
