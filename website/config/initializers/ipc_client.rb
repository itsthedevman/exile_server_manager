# frozen_string_literal: true

#
# IpcClient is a process-lifetime singleton (one cached NATS connection plus its
# background reader thread), so it lives in lib/ and is required once here rather
# than autoloaded. The autoloader ignores lib/ipc_client* (see
# config/application.rb) so hot reloads never wipe the class or orphan its
# connection. Load order: the class first, then the nested error types that
# reopen it.
#
require Rails.root.join("lib/ipc_client")
require Rails.root.join("lib/ipc_client/remote_error")
require Rails.root.join("lib/ipc_client/unreachable")
