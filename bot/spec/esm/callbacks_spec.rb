# frozen_string_literal: true

describe ESM::Callbacks do
  let(:object) { Callback.new }

  before do
    object.instance_variable_set(:@tracker, [])
  end

  describe "#register_callbacks" do
    it "has registered callbacks" do
      callbacks = object.class.__callbacks
      expect(callbacks).not_to be_blank

      expect(callbacks).to eq({before_execute: [{code: :method_to_call_from_class, on_instance: nil}], after_execute: []})
    end
  end

  describe "#add_callback" do
    it "adds a callback (method)" do
      object.add_callback(:before_execute, :method_to_call_on_before_execute)
      callbacks = object.__callbacks[:before_execute]
      expect(callbacks).not_to be_blank
      expect(callbacks.size).to eq(2)
      expect(callbacks).to eq([{code: :method_to_call_from_class, on_instance: nil}, {code: :method_to_call_on_before_execute, on_instance: nil}])
    end

    it "adds a callback (block)" do
      object.add_callback(:before_execute) do
        true
      end

      callbacks = object.__callbacks[:before_execute]
      expect(callbacks.size).to eq(2)
      expect(callbacks).not_to be_blank
    end

    it "supports adding callbacks on the class level" do
      expect(object.class.respond_to?(:add_callback)).to eq(true)
    end
  end

  describe "#run_callback" do
    it "adds and run the callbacks" do
      tracker = object.instance_variable_get(:@tracker)
      object.add_callback(:before_execute, :method_to_call_on_before_execute)
      object.add_callback(:after_execute, :method_to_call_on_after_execute)
      object.add_callback(:before_execute) { tracker << "before_execute_2" }
      object.add_callback(:after_execute) { tracker << "after_execute_2" }

      expect { object.run_callback(:before_execute) }.not_to raise_error
      expect { object.run_callback(:after_execute) }.not_to raise_error

      expect(tracker).to eq([
        "from_class",
        "before_execute",
        "before_execute_2",
        "after_execute",
        "after_execute_2"
      ])
    end
  end

  describe "#remove_callback" do
    it "removes the callback" do
      object.add_callback(:before_execute, :method_to_call_on_before_execute)
      callbacks = object.__callbacks[:before_execute]
      expect(callbacks.size).to eq(2)

      object.remove_callback(:before_execute, :method_to_call_on_before_execute)

      callbacks = object.__callbacks[:before_execute]
      expect(callbacks.size).to eq(1)
    end
  end
end
