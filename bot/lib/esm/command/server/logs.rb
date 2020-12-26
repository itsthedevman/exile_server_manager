# frozen_string_literal: true

module ESM
  module Command
    module Server
      class Logs < ESM::Command::Base
        type :admin
        limit_to :text
        requires :registration

        # Since the argument is a modified target, the logic for nil_target_user will trigger
        skip_check :nil_target_user

        define :enabled, modifiable: true, default: true
        define :whitelist_enabled, modifiable: true, default: true
        define :whitelisted_role_ids, modifiable: true, default: []
        define :allowed_in_text_channels, modifiable: true, default: true
        define :cooldown_time, modifiable: true, default: 2.seconds

        argument :server_id

        # In order to utilize the `#target_user` logic, the argument must have a name as target.
        argument :target, regex: /.+/, description: "commands.logs.arguments.query", multiline: true, display_as: :query

        def discord
          query = ""

          # If the target was given, check to make sure they're registered and then set the steam_uid
          if target_user
            @checks.registered_target_user! if target_user.is_a?(Discordrb::User)
            query = target_user.steam_uid
          else
            # Escape any regex in the "query"
            query = Regexp.quote(@arguments.target)
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
        def server
          check_for_no_logs!

          @log = ESM::Log.create!(server_id: target_server.id, search_text: @arguments.target, requestors_user_id: current_user.esm_user.id)

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
          check_failed!(:no_logs, user: current_user.mention) if @response.second.blank?
        end

        def parse_logs
          @response[1..].each do |entry|
            log_date = entry.date

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
            parsed_entry = { timestamp: "", line_number: log.line, entry: "" }

            # Pull timestamp from file and remove metadata
            if match = log.entry.match(ESM::Regex::LOG_TIMESTAMP)
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
      end
    end
  end
end
