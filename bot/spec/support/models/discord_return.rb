# frozen_string_literal: true

# The ruby version of my C# class
class DiscordReturn
  def initialize(**args)
    @command_id = args[:commandID]
    @command = args[:command]
    @parameters = args[:parameters]
    @error = args[:error]
    @ignore = args[:ignore]
  end

  def to_json(obj = nil)
    return JSON.generate(obj) if obj.present?

    {
      commandID: @command_id,
      command: @command,
      parameters: @parameters,
      error: @error,
      ignore: @ignore
    }.to_json
  end
end
