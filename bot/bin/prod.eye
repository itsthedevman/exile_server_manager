# frozen_string_literal: true

Eye.config do
  logger "/home/wolf/esm_bot/current/log/eye.log"
end

Eye.application "esm" do
  working_dir "/home/wolf/esm_bot/current"
  trigger :flapping, times: 10, within: 1.minute, retry_in: 10.minutes
  check :cpu, every: 10.seconds, below: 100, times: 3

  process :esm do
    daemonize true
    pid_file "esm.pid"
    stdall "log/stdall.log"
    start_command "source .env.prod && bundle exec ruby bin/start_prod.rb"
    stop_command "kill -9 {PID}"
  end
end
