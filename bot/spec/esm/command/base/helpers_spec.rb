# frozen_string_literal: true

describe ESM::Command::Base::Helpers do
  include_context "command" do
    let!(:command_class) { ESM::Command::Test::ArgumentDisplayName }
  end

  describe "#argument?" do
    context "when the argument exists and the argument's name is given" do
      it "returns true" do
        expect(command.argument?(:argument_name)).to be(true)
      end
    end

    context "when the argument exists and the argument's display name is given" do
      it "returns true" do
        expect(command.argument?(:display_name)).to be(true)
      end
    end

    context "when the argument does not exists" do
      it "returns false" do
        expect(command.argument?(:does_not_exist)).to be(false)
      end
    end
  end
end
