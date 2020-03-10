# frozen_string_literal: true

module ESM
  class Embed
    TAB = "\u200B\u200B\u200B\u200B"
    module Limit
      TITLE_LENGTH_MAX = 256
      DESCRIPTION_LENGTH_MAX = 2048
      FIELD_NAME_LENGTH_MAX = 256
      FIELD_VALUE_LENGTH_MAX = 1024
    end

    ###########################
    # Class methods
    ###########################
    def self.build(type = nil, **attributes)
      embed = ESM::Embed.new

      if block_given?
        yield(embed)
      else
        embed.build_from_template(type, attributes)
      end

      embed
    end

    ###########################
    # Instance methods
    ###########################
    attr_reader :title, :description, :image, :thumbnail, :footer, :color
    attr_accessor :fields, :author, :url, :timestamp

    def initialize
      @title = nil
      @description = nil
      @fields = []
      @footer = nil
      @author = nil
      @image = nil
      @thumbnail = nil
      @color = ESM::Color::Toast::BLUE
      @url = nil
      @timestamp = DateTime.now
      super
    end

    def title=(text)
      @title = text.truncate(Limit::TITLE_LENGTH_MAX, separator: " ")
    end

    def description=(text)
      text = text.join("\n") if text.is_a?(Array)
      @description = text.truncate(Limit::DESCRIPTION_LENGTH_MAX)
    end

    def add_field(name: nil, value:, inline: false)
      # This will make the name appear empty
      name = "\u200B" if name.nil?
      return add_field_array(name: name, values: value, inline: inline) if value.is_a?(Array)

      store_field(name: name, value: value, inline: inline)
    end

    def set_footer(text: nil, icon_url: nil)
      @footer = Discordrb::Webhooks::EmbedFooter.new(text: text, icon_url: icon_url)
    end

    def footer=(text)
      set_footer(text: text)
    end

    def set_author(name:, url: nil, icon_url: nil)
      @author = Discordrb::Webhooks::EmbedAuthor.new(name: name, url: url, icon_url: icon_url)
    end

    def image=(url)
      @image = Discordrb::Webhooks::EmbedImage.new(url: url)
    end

    def thumbnail=(url)
      @thumbnail = Discordrb::Webhooks::EmbedThumbnail.new(url: url)
    end

    def color=(color)
      @color =
        if color.is_a?(Symbol) && ESM::Color::Toast.const_defined?(color.to_s.upcase)
          ESM::Color::Toast.const_get(color.to_s.upcase)
        else
          color
        end
    end

    def transfer(embed)
      # And you can't do `embed = new_embed`
      embed.title = self.title if self.title
      embed.description = self.description if self.description
      embed.url = self.url if self.url
      embed.timestamp = self.timestamp if self.timestamp
      embed.color = self.color if self.color
      embed.footer = self.footer if self.footer
      embed.image = self.image if self.image
      embed.thumbnail = self.thumbnail if self.thumbnail
      embed.author = self.author if self.author
      embed.fields = self.fields if self.fields

      embed
    end

    def to_s
      output = ""
      output += "Title (#{self.title.size}): #{self.title}\n" if self.title
      output += "Description (#{self.description.size}): #{self.description}\n" if self.description

      if self.fields
        output += "Fields:\n"
        self.fields.each_with_index do |field, index|
          output += "\t##{index + 1}"
          output += " <inline>" if field.inline

          output += "\n\t  Name (#{field.name.size}): #{field.name}"
          output += "\n\t  Value (#{field.value.size}): #{field.value}\n"
        end
      end

      # Add the metadata
      if metadata?
        output += "Metadata:\n"
        output += "\tTimestamp: #{self.timestamp}\n" if self.timestamp
        output += "\tColor: #{self.color}\n" if self.color
        output += "\tImage: #{self.image.url}\n" if self.image
        output += "\tThumbnail: #{self.thumbnail.url}\n" if self.thumbnail
        output += "\tURL: #{self.url}\n" if self.url
        output += "\tFooter: #{self.footer.text}" if self.footer
      end

      output
    end

    def build_from_template(type, **attributes)
      case type
      when :error
        self.color = :red
      end

      attributes.each do |attr_name, attr_value|
        self.send("#{attr_name}=", attr_value)
      end
    end

    private

    def metadata?
      self.timestamp.present? || self.color.present? || self.image.present? || self.thumbnail.present? || self.url.present?
    end

    def add_field_array(name:, values:, inline:)
      field = { name: name, value: "", inline: inline }

      values.each do |value|
        value += "\n"

        if field[:value].size + value.size >= Limit::FIELD_VALUE_LENGTH_MAX
          store_field(field)
          field = { name: "#{name} #{t(:continued)}", value: "", inline: inline }
        end

        field[:value] += value
      end

      store_field(field)
    end

    def store_field(name:, value:, inline:)
      # to_s to ensure a string
      @fields << Discordrb::Webhooks::EmbedField.new(
        name: name.to_s.truncate(Limit::FIELD_NAME_LENGTH_MAX, separator: " "),
        value: value.to_s.truncate(Limit::FIELD_VALUE_LENGTH_MAX, separator: " "),
        inline: inline
      )
    end
  end
end
