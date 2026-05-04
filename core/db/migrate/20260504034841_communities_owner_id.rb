# frozen_string_literal: true

class CommunitiesOwnerID < ActiveRecord::Migration[8.1]
  def change
    change_table(:communities) do |t|
      t.belongs_to :owner_user, foreign_key: {to_table: :users}, index: true
    end
  end
end
