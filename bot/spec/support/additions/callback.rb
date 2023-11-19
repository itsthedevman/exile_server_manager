# frozen_string_literal: true

class Callback
  include ESM::Callbacks

  register_callbacks :before_execute, :after_execute
  add_callback :before_execute, :method_to_call_from_class

  def method_to_call_from_class
    @tracker << "from_class"
  end

  def method_to_call_on_before_execute
    @tracker << "before_execute"
  end

  def method_to_call_on_after_execute
    @tracker << "after_execute"
  end
end
