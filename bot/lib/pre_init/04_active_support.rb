# frozen_string_literal: true

ActiveSupport::Cache.format_version = 7.1

Time.zone_default = Time.find_zone!("UTC")

ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.acronym("ESM")
  inflect.acronym("ID")
  inflect.acronym("UID")
end
