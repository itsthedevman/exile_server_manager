# frozen_string_literal: true

[:trace, :debug, :info, :warn, :error].each do |severity|
  define_method(:"#{severity}!") do |content = {}|
    __log(severity, caller_locations(1, 1).first, content)
  end
end

# Used internally by logging methods. Do not call manually
def __log(severity, caller_data, content)
  if content.is_a?(Hash) && content[:error].is_a?(StandardError)
    e = content[:error]

    content[:error] = {
      class: e.class,
      message: e.message,
      backtrace: ESM.backtrace_cleaner.clean(e.backtrace)
    }
  end

  caller_class = caller_data
    .path
    .sub("#{__dir__}/", "")
    .sub(".rb", "")
    .classify

  caller_method = caller_data.label.gsub("block in ", "")

  ESM.logger.send(severity, "#{caller_class}##{caller_method}:#{caller_data.lineno}") do
    if content.is_a?(Hash)
      ESM::JSON.pretty_generate(content).presence || ""
    else
      content || ""
    end
  end
end
