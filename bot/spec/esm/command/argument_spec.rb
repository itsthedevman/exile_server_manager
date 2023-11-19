# frozen_string_literal: true

describe ESM::Command::Argument do
  let!(:command_class) { ESM::Command::Test::ArgumentDescriptions }
  let!(:command) { command_class.new }

  subject(:argument) { new_argument }

  def transform_and_validate!(content)
    argument.transform_and_validate!(content, command)
  end

  def new_argument(name = :with_locale, type = nil, **opts)
    described_class.new(name, type, **{command_class: command_class}.merge(opts))
  end

  describe "DEFAULT_TEMPLATE" do
    it "is always provided as a base template for arguments" do
      described_class::DEFAULT_TEMPLATE.each do |key, value|
        expect(argument.public_send(key)).to eq(value)
      end
    end
  end

  describe "TEMPLATES" do
    context "when the argument name is in TEMPLATES" do
      subject(:argument) { new_argument(:community_id) }

      it "merged into the base template" do
        expect(argument.checked_against).to eq(described_class::TEMPLATES[:community_id][:checked_against])
      end
    end

    context "when the argument :template option is in TEMPLATES" do
      subject(:argument) { new_argument(template: :community_id) }

      it "merged into the base template" do
        expect(argument.checked_against).to eq(described_class::TEMPLATES[:community_id][:checked_against])
      end
    end
  end

  context "when opts are provided that are already set by TEMPLATE and DEFAULT_TEMPLATE" do
    subject(:argument) { new_argument(:community_id, checked_against: "HELLO GORDON!") }

    it "overwrites them" do
      expect(argument.checked_against).to eq("HELLO GORDON!")
    end
  end

  context "when the type is not provided" do
    it "defaults to string" do
      expect(argument.type).to eq(:string)
    end
  end

  context "when the type is provided" do
    subject(:argument) { new_argument(:with_locale, :integer) }

    it "uses the type" do
      expect(argument.type).to eq(:integer)
    end
  end

  context "when :required is not provided" do
    it "defaults to false" do
      expect(argument.required?).to be(false)
      expect(argument.required_by_bot?).to be(false)
      expect(argument.required_by_discord?).to be(false)
    end
  end

  context "when :required is false" do
    subject(:argument) { new_argument(required: false, optional_text: "") }

    it "is optional" do
      expect(argument.optional?).to be(true)
      expect(argument.required?).to be(false)
      expect(argument.required_by_bot?).to be(false)
      expect(argument.required_by_discord?).to be(false)
    end

    it "defaults optional text" do
      expect(argument.optional_text).to eq("This argument is optional.")
    end
  end

  context "when :required is true" do
    subject(:argument) { new_argument(required: true) }

    it "is required" do
      expect(argument.required?).to be(true)
      expect(argument.required_by_bot?).to be(true)
      expect(argument.required_by_discord?).to be(true)
      expect(argument.optional?).to be(false)
    end

    it "defaults optional_text to an empty string" do
      expect(argument.optional_text).to be_blank
    end
  end

  context "when :required is a Hash" do
    subject(:argument) { new_argument(required: {discord: false, bot: true}) }

    it "is expected to be required by the bot but not discord" do
      expect(argument.required?).to be(true)
      expect(argument.required_by_bot?).to be(true)
      expect(argument.required_by_discord?).to be(false)
      expect(argument.optional?).to be(false)
    end
  end

  context "when :template is provided" do
    subject(:argument) { new_argument(template: :community_id) }

    it "pulls the defaults from the template and uses them" do
      expect(argument.name).to eq(:with_locale)
      expect(argument.checked_against).to eq(ESM::Regex::COMMUNITY_ID)
    end
  end

  context "when :description is not provided" do
    context "and there is a locale entry defined" do
      it "uses the description from the locales" do
        expect(argument.description).to eq("An argument description")
      end
    end

    context "and there is no locale entry defined" do
      subject(:argument) { new_argument(:test_name) }

      it "defaults to an empty string and promptly fails validation" do
        expect { argument }.to raise_error(
          ArgumentError, "#{command_class}:argument.test_name - description must be at least 1 character long"
        )
      end
    end
  end

  context "when :description is provided" do
    context "and the description is a locale path" do
      subject(:argument) do
        new_argument(
          :with_locale,
          description: "commands.argument_descriptions.arguments.with_locale.description_extra"
        )
      end

      it "looks up and uses the defined locale" do
        expect(argument.description).to eq("An argument description extra")
      end
    end

    context "and the description is not a locale path" do
      subject(:argument) { new_argument(description: "This is a testing description") }

      it "uses the provided text" do
        expect(argument.description).to eq("This is a testing description")
      end
    end

    context "and is over 100 characters in length" do
      subject(:argument) { new_argument(:test_name, description: "1" * 101) }

      it "raises an exception" do
        expect { argument }.to raise_error(
          ArgumentError, "#{command_class}:argument.test_name - description cannot be longer than 100 characters"
        )
      end
    end

    context "and is not 1 character in length" do
      subject(:argument) { new_argument(:test_name, description: "") }

      it "raises an exception" do
        expect { argument }.to raise_error(
          ArgumentError, "#{command_class}:argument.test_name - description must be at least 1 character long"
        )
      end
    end
  end

  context "when :description_extra is provided" do
    context "and the extra description is a locale path" do
      subject(:argument) do
        new_argument(
          :with_locale,
          description_extra: "commands.argument_descriptions.arguments.with_locale.optional_text"
        )
      end

      it "looks up and uses the defined locale" do
        expect(argument.description_extra).to eq("An argument optional text")
      end
    end

    context "and the extra description is not a locale path" do
      subject(:argument) { new_argument(description_extra: "This is description extra") }

      it "uses the provided text" do
        expect(argument.description_extra).to eq("This is description extra")
      end
    end
  end

  context "when :optional_text is provided" do
    context "and the optional text is a locale path" do
      subject(:argument) do
        new_argument(
          :with_locale,
          optional_text: "commands.argument_descriptions.arguments.with_locale.description"
        )
      end

      it "looks up and uses the defined locale" do
        expect(argument.optional_text).to eq("An argument description")
      end
    end

    context "and the optional text is not a locale path" do
      subject(:argument) { new_argument(optional_text: "This is optional text") }

      it "uses the provided text" do
        expect(argument.optional_text).to eq("This is optional text")
      end
    end
  end

  context "when :optional_text is not provided" do
    subject(:argument) { new_argument(optional_text: "") }

    it "defaults the text" do
      expect(argument.optional_text).to eq("This argument is optional.")
    end
  end

  context "when :display_name is provided" do
    subject(:argument) { new_argument(display_name: :different_name) }

    it "uses the display name instead of the given name" do
      expect(argument.name).to eq(:with_locale)
      expect(argument.display_name).to eq(:different_name)
      expect(argument.to_s).to eq("different_name")
    end
  end

  context "when :display_name is not provided" do
    it "uses the given name" do
      expect(argument.name).to eq(:with_locale)
      expect(argument.display_name).to eq(:with_locale)
      expect(argument.to_s).to eq("with_locale")
    end
  end

  context "when :default is provided" do
    subject(:argument) { new_argument(default: "foobar") }

    context "and the input is blank" do
      it "#default_value is expected to be set" do
        expect(argument.default_value).to be("foobar")
      end

      it "#default_value? is expected to be true" do
        expect(argument.default_value?).to be(true)
      end

      it "uses the default" do
        expect(transform_and_validate!(nil)).to eq("foobar")
        expect(transform_and_validate!("")).to eq("foobar")
      end
    end

    context "and the input is present" do
      it "uses the input" do
        expect(transform_and_validate!("testing")).to eq("testing")
      end
    end
  end

  context "when :default is not provided" do
    it "#default_value is expected to be nil" do
      expect(argument.default_value).to be(nil)
    end

    it "#default_value? is expected to be false" do
      expect(argument.default_value?).to be(false)
    end

    it "defaults to nil" do
      expect(transform_and_validate!(nil)).to eq(nil)
      expect(transform_and_validate!("a")).to eq("a")
    end
  end

  context "when :preserve_case is true" do
    subject(:argument) { new_argument(preserve_case: true) }

    it "#preserve_case? is expected to be true" do
      expect(argument.preserve_case?).to be(true)
    end

    it "does not convert string input to lowercase" do
      expect(transform_and_validate!("Hello World!")).to eq("Hello World!")
    end
  end

  context "when :preserve_case is false" do
    it "#preserve_case? is expected to be false" do
      expect(argument.preserve_case?).to be(false)
    end

    it "converts string input to lowercase" do
      expect(transform_and_validate!("Hello World!")).to eq("hello world!")
    end
  end

  context "when :modifier is provided" do
    subject(:argument) do
      new_argument(
        :with_locale,
        modifier: ->(content) { content + "1" }
      )
    end

    it "#modifier? is expected to be true" do
      expect(argument.modifier?).to be(true)
    end

    it "runs the input through the modifier and stores the return as the new input" do
      expect(transform_and_validate!("testing")).to eq("testing1")
    end
  end

  context "when :modifier is not provided" do
    it "#modifier? is expected to be false" do
      expect(argument.modifier?).to be(false)
    end

    it "skips running the input through the modifier" do
      expect(transform_and_validate!("testing")).to eq("testing")
    end
  end

  context "when :choices is provided" do
    subject(:argument) { new_argument(choices: {value_1: "Display 1", value_2: "Display 2"}) }

    it "swaps the key and value for Discord and stores it in options" do
      choices = argument.options[:choices]

      expect(choices).to be_kind_of(Hash)
      expect(choices).to include("Display 1" => "value_1", "Display 2" => "value_2")
    end
  end

  context "when :min_value is provided" do
    context "and type is :integer" do
      subject(:argument) { new_argument(:with_locale, :integer, min_value: 2) }

      it "stores it in options" do
        expect(argument.options[:min_value]).to eq(2)
      end
    end

    context "and type is not :integer" do
      subject(:argument) { new_argument(min_value: 2) }

      it "raises an exception" do
        expect { argument }.to raise_error(
          ArgumentError,
          "#{command_class}:argument.with_locale - min/max values can only be used with integer or number types"
        )
      end
    end
  end

  context "when :max_value is provided" do
    context "and type is :integer" do
      subject(:argument) { new_argument(:with_locale, :integer, max_value: 2) }

      it "stores it in options" do
        expect(argument.options[:max_value]).to eq(2)
      end
    end

    context "and type is not :integer" do
      subject(:argument) { new_argument(max_value: 2) }

      it "raises an exception" do
        expect { argument }.to raise_error(
          ArgumentError,
          "#{command_class}:argument.with_locale - min/max values can only be used with integer or number types"
        )
      end
    end
  end

  context "when :checked_against is not a Hash" do
    context "and the argument is required and the input is provided" do
      subject(:argument) { new_argument(required: true, checked_against: "foob") }

      it "passes validation" do
        transform_and_validate!("foobar")
      end

      it "fails validation" do
        expect { transform_and_validate!("testing") }.to raise_error(ESM::Exception::InvalidArgument)
      end
    end

    context "and the argument is optional and the input is blank" do
      subject(:argument) { new_argument(checked_against: "foob") }

      it "skips validation" do
        transform_and_validate!("")
      end
    end
  end

  context "when :checked_against is provided a String" do
    subject(:argument) { new_argument(checked_against: "test") }

    context "and the input matches" do
      it "passes validation" do
        transform_and_validate!("testing")
      end
    end

    context "and the input does not match" do
      it "fails and raises an exception" do
        expect { transform_and_validate!("foobar") }.to raise_error(ESM::Exception::InvalidArgument)
      end
    end
  end

  context "when :checked_against is provided a Regexp" do
    subject(:argument) { new_argument(checked_against: /\d+/) }

    context "and the input matches" do
      it "passes validation" do
        transform_and_validate!("12345")
      end
    end

    context "and the input does not match" do
      it "fails and raises an exception" do
        expect { transform_and_validate!("a") }.to raise_error(ESM::Exception::InvalidArgument)
      end
    end
  end

  context "when :checked_against is provided a Proc/Lambda" do
    subject(:argument) { new_argument(checked_against: ->(content) { content == "54321" }) }

    context "and the result of the block is truthy" do
      it "passes validation" do
        transform_and_validate!("54321")
      end
    end

    context "and the result of the block is falsey" do
      it "fails and raises an exception" do
        expect { transform_and_validate!("a") }.to raise_error(ESM::Exception::InvalidArgument)
      end
    end
  end

  context "when :checked_against is provided an Array" do
    subject(:argument) { new_argument(checked_against: ["foo", "bar", "baz"]) }

    context "and the input is in the array" do
      it "passes validation" do
        transform_and_validate!("baz")
      end
    end

    context "and the input is not in the array" do
      it "fails and raises an exception" do
        expect { transform_and_validate!("testing") }.to raise_error(ESM::Exception::InvalidArgument)
      end
    end
  end

  context "when :checked_against_if is provided" do
    subject(:argument) do
      new_argument(
        :with_locale,
        checked_against: ->(content) { content.nil? }, # Set up to fail
        checked_against_if: ->(arg, content) { content.match?("test") }
      )
    end

    context "when :checked_against_if returns a truthy value" do
      it "continues to validation" do
        expect { transform_and_validate!("test") }.to raise_error(ESM::Exception::InvalidArgument)
      end
    end

    context "when :checked_against_if returns a falsey value" do
      it "skips validation" do
        transform_and_validate!("foobar")
      end
    end
  end

  context "when :checked_against_if is nil" do
    subject(:argument) { new_argument(checked_against: "test", checked_against_if: nil) }

    it "skips validation" do
      transform_and_validate!("foobar")
    end
  end
end
