# frozen_string_literal: true

module ESM
  class ServerMod < ApplicationRecord
    attribute :server_id, :integer
    attribute :mod_name, :text
    attribute :mod_link, :text, default: nil
    attribute :mod_version, :string, default: nil
    attribute :mod_required, :boolean, default: false
    attribute :created_at, :datetime
    attribute :updated_at, :datetime

    belongs_to :server
  end
end
