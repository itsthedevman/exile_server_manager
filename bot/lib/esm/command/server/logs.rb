# frozen_string_literal: true

module ESM
  module Command
    module Server
      class Logs < ApplicationCommand
        # Handles German, Italian, Spanish, and French
        TRANSLATED_MONTHS = {
          "gen" => "jan",
          "ene" => "jan",
          "fév" => "feb",
          "mär" => "mar",
          "abr" => "apr",
          "avr" => "apr",
          "mai" => "may",
          "mag" => "may",
          "juin" => "jun",
          "giu" => "jun",
          "lug" => "jul",
          "juil" => "jul",
          "aoû" => "aug",
          "ago" => "aug",
          "set" => "sep",
          "ott" => "oct",
          "okt" => "oct",
          "dic" => "dec",
          "dez" => "dec",
          "déc" => "dec"
        }.freeze

        #################################
        #
        # Arguments (required first, then order matters)
        #

        # See Argument::TEMPLATES[:target]
        # Checked against: This is removed because target can be a standard target or anything else
        argument :target, display_name: :for, checked_against: nil

        # See Argument::TEMPLATES[:server_id]
        argument :server_id, display_name: :on

        #
        # Configuration
        #

        change_attribute :allowlist_enabled, default: true

        command_namespace :server, :admin, command_name: :search_logs
        command_type :admin

        limit_to :text

        # Since the argument is a modified target, the logic for nil_target_user will trigger
        skip_action :nil_target_user

        #################################

        def on_execute
          # If the target was given, check to make sure they're registered and then set the steam_uid
          search =
            if target_user
              check_for_registered_target_user! if target_user.is_a?(ESM::User)

              target_user.steam_uid
            else
              # Escape any regex in the "search query"
              Regexp.quote(arguments.target)
            end

          message = ESM::Message.new.set_type(:search).set_data(search:)
          log_results = send_to_target_server!(message).data.results

          check_for_no_logs!(log_results)

          log = ESM::Log.create!(
            server_id: target_server.id,
            search_text: arguments.target,
            requestors_user_id: current_user.id
          )

          create_log_entries(log, log_results)

          embed =
            ESM::Embed.build do |e|
              e.title = "Log parsing for `#{target_server.server_id}` completed"

              e.description = <<~STRING
                You may review the results here:
                #{log.link}
                _Link expires on `#{log.expires_at.strftime(ESM::Time::Format::TIME)}`_
              STRING
            end

          reply(embed)
        end

        private

        def check_for_no_logs!(logs)
          raise_error!(:no_logs, user: current_user.mention) if logs.blank?
        end

        def create_log_entries(log, log_results)
          log_results = log_results.group_by { |r| r[:file_name] }

          # Remove file_name and sort
          log_results.transform_values! do |entries|
            entries.each { |e| e.delete(:file_name) }
              .sort_by { |e| e[:line_number] }
          end

          log_results.each do |file_name, entries|
            next if entries.blank?

            ESM::LogEntry.create!(log:, file_name:, entries:)
          end
        end

        ###########################################################################################

        module V1
          def on_execute
            query = ""

            # If the target was given, check to make sure they're registered and then set the steam_uid
            if target_user
              check_for_registered_target_user! if target_user.is_a?(ESM::User)

              query = target_user.steam_uid
            else
              # Escape any regex in the "query"
              query = Regexp.quote(arguments.target)
            end

            deliver!(search: query, length: 14)
          end

          # Response:
          # 0: The search parameters
          # 1..-1: The parsed logs
          #   date: <String> October 11 2020
          #   file_name (Exile_TradingLog.log): <Array>
          #     line: <Integer>
          #     entry: <String>
          #     date: <String 2020-10-11>
          def on_response
            check_for_no_logs!

            @log = ESM::Log.create!(server_id: target_server.id, search_text: arguments.target, requestors_user_id: current_user.id)

            parse_logs

            embed =
              ESM::Embed.build do |e|
                e.title = "Log parsing for `#{target_server.server_id}` completed"
                e.description = "You may review the results here:\n#{@log.link}\n\n_Link expires on `#{@log.expires_at.strftime(ESM::Time::Format::TIME)}`_"
              end

            reply(embed)
          end

          private

          def check_for_no_logs!
            raise_error!(:no_logs, user: current_user.mention) if @response.second.blank?
          end

          def parse_logs
            @response[1..].each do |entry|
              log_date = parse_log_entry_date(entry)

              # Convert the entry into a hash to drop the date field
              entry = entry.to_h.with_indifferent_access.without(:date)
              entry.each do |file_name, logs|
                parse_log(file_name: file_name.to_s, logs: logs, log_date: log_date)
              end
            end
          end

          def parse_log(file_name:, logs:, log_date:)
            return [] if logs.blank?

            entries = []
            log_entry = ESM::LogEntry.new(log_id: @log.id, log_date: log_date, file_name: file_name)

            logs.each do |log|
              parsed_entry = {timestamp: "", line_number: log.line, entry: ""}

              # Pull timestamp from file and remove metadata
              if (match = log.entry.match(ESM::Regex::LOG_TIMESTAMP))
                parsed_entry[:timestamp] = DateTime.strptime("#{log.date} #{match["time"]} #{match["zone"]}", "%Y-%m-%d %H:%M:%S %Z")
                log.entry = log.entry.gsub(ESM::Regex::LOG_TIMESTAMP, "")
              end

              # No fancy parsing, just bring over the standard log line
              parsed_entry[:entry] = log.entry

              # Store the log
              entries << parsed_entry
            end

            # Persist the entries to the database
            log_entry.update!(entries: entries)
          end

          # The DLL sends over this date as Month Day Year
          # Problem is, Ruby parses dates by checking the first 3 letters of the month and only supports English.
          # This method converts the date by translating the first 3 letters to an English month
          def parse_log_entry_date(entry)
            date = entry.date

            # Scan the date for the translations. Replacing the first three letters
            TRANSLATED_MONTHS.each do |key, value|
              break date = date.sub(/#{key}/i, value) if date.match?(/^(#{key}).*\b/i)
            end

            Date.parse(date)
          end
        end
      end
    end
  end
end
