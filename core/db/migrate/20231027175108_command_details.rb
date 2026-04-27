# frozen_string_literal: true

class CommandDetails < ActiveRecord::Migration[7.0]
  def change
    drop_table(:command_caches) # rubocop:disable Rails/ReversibleMigration

    # prefixed with command because of shared namings (type, attributes)
    create_table :command_details do |t|
      t.string :command_name, index: true
      t.string :command_type
      t.string :command_category
      t.string :command_limited_to
      t.text :command_description
      t.text :command_usage
      t.json :command_examples
      t.json :command_arguments
      t.json :command_attributes
      t.json :command_requirements

      t.timestamps
    end
  end
end
