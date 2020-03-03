# frozen_string_literal: true

describe ESM::Database do
  it "should be connected" do
    ESM::Database.connected?
  end
end
