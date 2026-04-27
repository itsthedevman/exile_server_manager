# frozen_string_literal: true

module ESM
  module Command
    module Test
      class ArgumentDescriptions < ApplicationCommand
        argument :with_locale
        argument :required, description: "This argument is required"
        argument :optional, description: "This argument is optional", default: nil
        argument :optional_default, default: "optional"
        argument :optional_text,
          description: "This argument is optional with text",
          default: nil,
          optional_text: "This has optional text"

        argument :display_name,
          description: "This argument has a different display name",
          display_name: :display_name

        def argument_descriptions
          <<~STRING.chomp
            **`<required>`**
            This argument is required.

            **`<?optional>`**
            This argument is optional.
            **Note:** This argument is optional.

            **`<?optional_default>`**
            **Note:** This argument is optional and it defaults to `optional`.

            **`<?optional_text>`**
            This argument is optional with text.
            **Note:** This has optional text

            **`<display_name>`**
            This argument has a different display name.
          STRING
        end
      end
    end
  end
end
