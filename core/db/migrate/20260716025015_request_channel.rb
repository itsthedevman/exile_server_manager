class RequestChannel < ActiveRecord::Migration[8.1]
  def change
    change_column_null :requests, :requested_from_channel_id, true
  end
end
