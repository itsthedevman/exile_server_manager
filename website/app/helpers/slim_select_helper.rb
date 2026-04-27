# frozen_string_literal: true

module SlimSelectHelper
  def data_from_collection_for_slim_select(collection, value_method, text_method, options = {})
    placeholder = options.delete(:placeholder)
    selected_value = options.delete(:selected)

    data = []
    data << {text: "", value: "", placeholder: true} if placeholder

    collection.each do |item|
      text =
        if text_method.is_a?(Proc)
          text_method.call(item)
        else
          item.public_send(text_method)
        end

      value =
        if value_method.is_a?(Proc)
          value_method.call(item)
        else
          item.public_send(value_method)
        end

      selected =
        if selected_value.is_a?(Proc)
          selected_value.call(item, value)
        else
          value == selected_value
        end

      selected = false if selected.nil?

      data << {text:, value:, selected:, **options}
    end

    data
  end

  def group_data_from_collection_for_slim_select(
    collection, group_method, value_method, text_method, options = {}
  )
    placeholder = options.delete(:placeholder)

    select_all = options.delete(:select_all)
    select_all = false if select_all.nil?

    closable = options.delete(:closable)
    closable = "off" if closable.nil?

    data = []
    data << {text: "", value: "", placeholder: true} if placeholder

    collection.each do |group, group_data|
      label =
        if group_method.is_a?(Proc)
          group_method.call(group)
        else
          group.public_send(group_method)
        end

      data << {
        label:,
        closable:,
        selectAll: select_all,
        options: data_from_collection_for_slim_select(
          group_data, value_method, text_method, options
        )
      }
    end

    data
  end

  def generate_community_select_data(all_communities, selected_id = nil, value_method: nil)
    value_method ||= :community_id

    text_method = ->(community) { "[#{community.community_id}] #{community.community_name}" }
    selected = selected_id ? ->(item, _value) { item.id == selected_id } : false

    data_from_collection_for_slim_select(
      all_communities, value_method, text_method,
      selected:, placeholder: true
    )
  end

  def generate_server_select_data(
    servers_by_community, selected_id = nil, value_method: nil, **options
  )
    group_label_method = ->(community) { "[#{community.community_id}] #{community.community_name}" }

    value_method ||= :server_id

    text_method = lambda do |server|
      "[#{server.server_id}] #{server.server_name || "Name not provided"}"
    end

    selected = selected_id ? ->(item, _value) { item.id == selected_id } : false

    group_data_from_collection_for_slim_select(
      servers_by_community, group_label_method, value_method, text_method,
      selected:, placeholder: true, **options
    )
  end

  def slim_select_stimulus_actions(controller_name)
    [
      "#{controller_name}:setSelected->slim-select#setSelected",
      "#{controller_name}:clearSelected->slim-select#clearSelected",
      "#{controller_name}:clearData->slim-select#clearData",
      "#{controller_name}:setData->slim-select#setData",
      "#{controller_name}:enable->slim-select#enable",
      "#{controller_name}:disable->slim-select#disable"
    ].join(" ")
  end
end
