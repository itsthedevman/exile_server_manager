# frozen_string_literal: true

class ServerSettingUpdaterEnabled < ActiveRecord::Migration[8.0]
  # Nullable with no database default on purpose. A config.yml key is only written when the owner has chosen a value
  # that differs from the default, so NULL is what "the owner has not touched this" looks like, and the key stays out
  # of the generated file. The updater treats a missing key as enabled, which makes NULL and true the same thing to
  # every server already running.
  def change
    add_column :server_settings, :updater_enabled, :boolean
  end
end
