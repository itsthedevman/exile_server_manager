# frozen_string_literal: true

[:trace, :debug, :info, :warn, :error].each do |severity|
  Kernel.module_eval <<-RUBY, __FILE__, __LINE__ + 1
    def #{severity}!(content = {})
      return unless ESM.logger.#{severity}?

      if content.is_a?(Hash) && (error = content[:error]) && error.is_a?(StandardError)
        content[:error] = {
          class: error.class,
          message: error.message,
          backtrace: ESM.backtrace_cleaner.clean(error.backtrace)
        }
      end

      caller_data = caller_locations(1, 1).first
      caller_class = caller_data.path.sub("\#{ESM.root}/lib/", "").sub(".rb", "").classify
      caller_method = caller_data.label.gsub("block in ", "")

      ESM.logger.#{severity}("\#{caller_class}#\#{caller_method}:\#{caller_data.lineno}") do
        if content.is_a?(Hash)
          ESM::JSON.pretty_generate(content).presence || ""
        else
          content || ""
        end
      end
    end
  RUBY
end
