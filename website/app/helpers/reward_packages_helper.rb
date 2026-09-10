# frozen_string_literal: true

module RewardPackagesHelper
  ##
  # Whether this server's owner gets the package editor rather than the single form that came before it.
  #
  # Keyed on the UI version an owner picks rather than the version their server reports, so packages can be built
  # before the server that will hand them out is updated. Nothing here reaches the game.
  #
  # @param server [ESM::Server]
  #
  # @return [Boolean]
  #
  def reward_packages_manageable?(server)
    server.ui_v2?
  end

  ##
  # Whether this server can actually deliver a vehicle, which decides whether the editor offers any.
  #
  # This one is keyed on the reported version, because `spawnReward` is SQF that shipped with it. Never enforced
  # locally, matching ServerVersion: a development extension reports whatever is built rather than what was released.
  #
  # @param server [ESM::Server]
  #
  # @return [Boolean]
  #
  def reward_packages_vehicles_supported?(server)
    return true if Rails.env.local?

    server.version?(ESM::Command::Server::Reward::MINIMUM_SERVER_VERSION)
  end

  ##
  # Why a server's editor is not offering vehicles, said to the person who can go fix it.
  #
  # @param server [ESM::Server]
  #
  # @return [String]
  #
  def reward_packages_vehicles_unsupported_message(server)
    if server.server_version.blank?
      return "#{server.server_id} has never connected, so ESM cannot tell whether it can spawn vehicles yet."
    end

    "#{server.server_id} is on #{server.display_version}. Handing a vehicle over needs " \
      "#{ESM::Command::Server::Reward::MINIMUM_SERVER_VERSION} or newer."
  end

  ##
  # The package a player gets for asking without a code. Every server has one, created along with the server.
  #
  # @param server [ESM::Server]
  #
  # @return [ESM::ServerReward, nil]
  #
  def reward_packages_default_for(server)
    server.server_rewards.to_a.find(&:default?)
  end

  ##
  # Every package a player has to know a code to claim, in the order those codes read.
  #
  # @param server [ESM::Server]
  #
  # @return [Array<ESM::ServerReward>]
  #
  def reward_packages_coded_for(server)
    server.server_rewards.to_a.reject(&:default?).sort_by { |package| package.reward_id.downcase }
  end

  ##
  # @return [ActiveSupport::SafeBuffer]
  #
  def reward_package_default_explanation
    safe_join([
      "Handed to anyone who runs ",
      command_usage(:reward, show_arguments: false),
      " without naming a package."
    ])
  end

  ##
  # What is missing when the default package holds nothing.
  #
  # An empty package is refused by the command and left off the player's dashboard, so an owner reading a row that
  # says nothing is looking at something that does not work rather than something they have not finished styling.
  #
  # @return [ActiveSupport::SafeBuffer]
  #
  def reward_package_default_empty_explanation
    safe_join([
      "Players who run ",
      command_usage(:reward, show_arguments: false),
      " without a code get nothing"
    ])
  end

  ##
  # @return [String]
  #
  def reward_package_coded_explanation
    "Claimed by typing the code, so only the players you give it to can find it."
  end

  ##
  # How this package reaches a player, said once under the editor's title.
  #
  # It is the same sentence the page already shows above each group, moved here so the field it is about can carry a
  # line short enough to sit under a half width input without wrapping three times.
  #
  # @param package [ESM::ServerReward]
  #
  # @return [String, ActiveSupport::SafeBuffer]
  #
  def reward_package_editor_subtitle(package)
    return reward_package_coded_explanation unless package.default?

    reward_package_default_explanation
  end

  ##
  # @param package [ESM::ServerReward]
  #
  # @return [String]
  #
  def reward_package_enabled_title(package)
    package.enabled? ? "Players can claim this package" : "Players cannot claim this package"
  end

  ##
  # @return [ActiveSupport::SafeBuffer]
  #
  def reward_package_command_cooldown_hint
    safe_join([
      "Without one, this package uses the cooldown set for ",
      command_usage(:reward, show_arguments: false),
      "."
    ])
  end

  ##
  # @param package [ESM::ServerReward]
  #
  # @return [String]
  #
  def reward_package_delete_confirmation(package)
    "Delete #{reward_package_name(package)}? The code #{package.reward_id} will stop working."
  end

  ##
  # Where the editor posts to. A package addresses itself by its code rather than its row, the same as everywhere else
  # a player or an owner names one.
  #
  # @param server [ESM::Server]
  # @param package [ESM::ServerReward]
  #
  # @return [String]
  #
  def reward_package_form_url(server, package)
    return community_server_rewards_path(current_community, server) if package.new_record?

    community_server_reward_path(current_community, server, package.reward_id)
  end

  ##
  # What a package or a claim holds, named rather than counted out.
  #
  # An owner scans this column to find the row they meant, and only then wants the amounts. Naming the buckets keeps
  # every row the same shape whatever is in it, and the amounts ride along in a tooltip so reading one costs a hover
  # instead of opening the editor.
  #
  # @param reward [ESM::ServerReward, ESM::ServerRewardClaim] anything holding reward contents
  #
  # @return [Array<Datum>] each carrying #label and #detail
  #
  def reward_content_badges(reward)
    contents = reward.contents

    currencies = {
      "Poptabs" => contents.player_poptabs,
      "Locker" => contents.locker_poptabs,
      "Respect" => contents.respect
    }

    badges = currencies.filter_map do |label, amount|
      {label:, detail: number_with_delimiter(amount)} if amount.positive?
    end

    if contents.items.present?
      badges << {
        label: "item".pluralize(contents.items.size).capitalize,
        detail: contents.items.join_map("\n") { |item| "#{item.quantity}x #{item.display_name}" }
      }
    end

    if contents.vehicles.present?
      badges << {
        label: "vehicle".pluralize(contents.vehicles.size).capitalize,
        detail: contents.vehicles.join_map("\n") do |vehicle|
          "#{vehicle.display_name} (#{reward_package_spawn_label(vehicle.spawn_location)})"
        end
      }
    end

    badges.map(&:to_datum)
  end

  ##
  # How often a player may take this package, in the owner's terms.
  #
  # @param package [ESM::ServerReward]
  #
  # @return [String]
  #
  def reward_package_cooldown_summary(package)
    return "Command default" if package.cooldown_time.nil?
    return "#{pluralize(package.cooldown_quantity, "use")} total" if package.cooldown_type == "times"

    "Once every #{pluralize(package.cooldown_quantity, package.cooldown_type.singularize)}"
  end

  ##
  # Where a vehicle goes, said the way the admin who configured it would say it. The player-facing wording answers
  # "what am I getting"; this one answers "what did I set".
  #
  # @param spawn_location [String]
  #
  # @return [String]
  #
  def reward_package_spawn_label(spawn_location)
    case spawn_location
    when "nearby"
      "spawns nearby"
    when "virtual_garage"
      "virtual garage"
    else
      "player decides"
    end
  end

  ##
  # The stored items as editor rows. The column is keyed by class name so it cannot hold a duplicate, while the editor
  # is a list of rows that can, which is why the two shapes are not the same one.
  #
  # @param package [ESM::ServerReward]
  #
  # @return [Array<Datum>] each carrying #classname and #quantity
  #
  def reward_package_item_rows(package)
    package.reward_items.map { |classname, quantity| {classname: classname.to_s, quantity:}.to_datum }
  end

  ##
  # The stored vehicles as editor rows.
  #
  # @param package [ESM::ServerReward]
  #
  # @return [Array<Datum>] each carrying #class_name and #spawn_location
  #
  def reward_package_vehicle_rows(package)
    package.reward_vehicles.map do |vehicle|
      {
        class_name: vehicle[:class_name].to_s,
        spawn_location: vehicle[:spawn_location].presence || "nearby"
      }.to_datum
    end
  end

  ##
  # A cooldown's unit. Counting uses is the odd one out, since it is a total rather than a rate, so it sits at the end
  # rather than at the top of a list an owner reads as "once every ...".
  #
  # @return [Array<Array(String, String)>]
  #
  def reward_package_cooldown_type_options
    units = ESM::Cooldown::TYPES - ["times"]

    units.map { |type| [type.humanize, type] } + [["Total uses", "times"]]
  end

  ##
  # Every destination an admin may set, including handing the choice to the player. The player's own picker offers
  # only the two they may choose between.
  #
  # @return [Array<Array(String, String)>]
  #
  def reward_package_spawn_location_options
    [
      ["Spawn it next to them", "nearby"],
      ["Store it in a virtual garage", "virtual_garage"],
      ["Let the player decide", "player_decides"]
    ]
  end
end
