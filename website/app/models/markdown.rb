# frozen_string_literal: true

class Markdown
  def self.to_html(markdown)
    return "" if markdown.blank?

    Kramdown::Document.new(markdown.gsub("\n", "<br>"))
      .to_html
      .gsub(/<p>|<\/p>/, "") # Remove the <p> tag that Kramdown adds
  end
end
