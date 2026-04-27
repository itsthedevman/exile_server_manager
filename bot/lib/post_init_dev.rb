# frozen_string_literal: true

timer = Timer.start!

#############################
# Setup
#############################

server = ESM::Server.all.first
ESM.redis.set("server_key", server.token.to_json) if server

info!("Completed in #{timer.stop!}s")
