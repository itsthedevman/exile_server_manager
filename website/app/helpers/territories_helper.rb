# frozen_string_literal: true

module TerritoriesHelper
  # Per-command display copy for the shared territory-command action flow (the
  # processing spinner, the settled result line, and the outcome toast). Adding a
  # new territory write is one row here plus its trigger partial - the machinery
  # in the _command_* partials is command-agnostic. The error_message branch of a
  # failure is shared (it's the extension's own rejection text), so only the
  # timeout hedge and the generic-catch line are per-command. `style` picks how
  # the in-flight and settled states render: :block is a full-width button (the
  # pay/upgrade sections), :inline is an icon-sized control (the member-list
  # actions, many to a modal).
  TERRITORY_COMMAND_COPY = {
    "pay" => {
      style: :block,
      progressive: "Paying…",
      past_tense: "Paid",
      processing_tone: "warning",
      success_toast: "Territory payment complete.",
      failure_title: "Payment failed",
      timeout_failure: "The server didn't respond in time. Check in-game before paying again.",
      generic_failure: "Something went wrong processing the payment. Please try again."
    },
    "upgrade" => {
      style: :block,
      progressive: "Upgrading…",
      past_tense: "Upgraded",
      processing_tone: "success",
      success_toast: "Territory upgraded.",
      failure_title: "Upgrade failed",
      timeout_failure: "The server didn't respond in time. Check in-game before upgrading again.",
      generic_failure: "Something went wrong processing the upgrade. Please try again."
    },
    "add" => {
      style: :block,
      progressive: "Sending…",
      past_tense: "Request sent",
      processing_tone: "info",
      success_toast: "Add request sent. They'll be added once they accept it.",
      failure_title: "Request failed",
      timeout_failure: "The server didn't respond in time. Check in-game before requesting again.",
      generic_failure: "Something went wrong sending the request. Please try again.",
      # A territory admin or self-add is processed by arma immediately, so the outcome reads as done, not pending.
      added: {past_tense: "Added", success_toast: "Player added to the territory."}
    },
    "promote" => {
      style: :inline,
      progressive: "Promoting…",
      past_tense: "Promoted",
      processing_tone: "success",
      success_toast: "Player promoted to moderator.",
      failure_title: "Promotion failed",
      timeout_failure: "The server didn't respond in time. Check in-game before promoting again.",
      generic_failure: "Something went wrong promoting the player. Please try again."
    },
    "demote" => {
      style: :inline,
      progressive: "Demoting…",
      past_tense: "Demoted",
      processing_tone: "secondary",
      success_toast: "Player demoted to build rights.",
      failure_title: "Demotion failed",
      timeout_failure: "The server didn't respond in time. Check in-game before demoting again.",
      generic_failure: "Something went wrong demoting the player. Please try again."
    },
    "remove" => {
      style: :inline,
      progressive: "Removing…",
      past_tense: "Removed",
      processing_tone: "danger",
      success_toast: "Player removed from the territory.",
      failure_title: "Removal failed",
      timeout_failure: "The server didn't respond in time. Check in-game before removing again.",
      generic_failure: "Something went wrong removing the player. Please try again."
    },
    "set_id" => {
      style: :inline,
      progressive: "Saving…",
      past_tense: "Renamed",
      processing_tone: "info",
      success_toast: "Territory ID updated.",
      failure_title: "Rename failed",
      timeout_failure: "The server didn't respond in time. Check in-game before renaming again.",
      generic_failure: "Something went wrong updating the territory ID. Please try again."
    }
  }.freeze

  # The member-list action buttons, keyed by action. Static face (icon, color,
  # tooltip); `confirm` is a proc so the destructive one can name the member it
  # targets. command_name maps to the <command>_member route via
  # #territory_member_command_path.
  MEMBER_ACTIONS = {
    promote: {
      command_name: "promote",
      icon: "arrow-up-circle",
      variant: "outline-success",
      label: "Promote to moderator"
    },
    demote: {
      command_name: "demote",
      icon: "arrow-down-circle",
      variant: "outline-secondary",
      label: "Demote to build rights"
    },
    remove: {
      command_name: "remove",
      icon: "x-circle",
      variant: "outline-danger",
      label: "Remove from territory",
      confirm: ->(member) { "Remove #{member.name} from the territory?" }
    }
  }.freeze

  # Which actions each role gets on the member list. Owner has none; a moderator
  # can be demoted or removed; a builder can be promoted or removed. Display-gate
  # only - arma enforces the actual rights and rejects an unauthorized call.
  MEMBER_ROLE_ACTIONS = {
    moderator: %i[demote remove],
    builder: %i[promote remove]
  }.freeze

  # A titled section panel inside the territory detail modal body. The header icon
  # carries an accent color so the panels aren't monochrome.
  def territory_section(title, icon:, color: "text-info", wrapper_class: "p-3 mb-3", &block)
    tag.div(class: class_names("bg-body-tertiary rounded-3", wrapper_class)) do
      safe_join([
        tag.div(class: "text-uppercase small fw-bold mb-3 d-flex align-items-center gap-2") do
          safe_join([tag.i(class: "bi bi-#{icon} #{color}"), tag.span(title)])
        end,
        capture(&block)
      ])
    end
  end

  # A labeled stat cell for the modal grids. `value` may be HTML (e.g. a
  # poptab-iconified price); `color` accents the value (e.g. money green).
  def territory_stat(label, value, color: nil, **args)
    tag.div(class: args[:class] || "col-6 col-md-4") do
      safe_join([
        tag.div(label, class: "text-secondary-emphasis small text-uppercase mb-1"),
        tag.div(value, class: class_names("fs-5 fw-semibold text-break", color))
      ])
    end
  end

  # Accent for the Overview status stat: green while the territory is secure, red
  # once its flag has been stolen.
  def territory_flag_status_color(territory)
    territory.stolen? ? "text-danger" : "text-success"
  end

  # The territory's level for the Overview stat, tagged with a muted "(max)" once
  # it can't be upgraded further. The Next level section hides at the ceiling, so
  # this is the only cue that a territory is maxed out.
  def territory_level_display(territory)
    return territory.level.to_s if territory.upgradeable?

    safe_join([territory.level.to_s, tag.span("(max)", class: "text-secondary-emphasis small ms-1")])
  end

  # Web-friendly timestamp, or a fallback when the territory has never been paid.
  def territory_datetime(time)
    return "Unknown" if time.nil?

    time.strftime("%b %-d, %Y at %H:%M")
  end

  # Date without the clock time. The payment due date drops the exact minute on
  # purpose: an exact "due at 19:08" invites "I paid right then and it didn't go
  # through, admin!" disputes the day alone doesn't.
  def territory_date(time)
    return "Unknown" if time.nil?

    time.strftime("%b %-d, %Y")
  end

  # Whether the viewer sees the add-member form. Only the owner and moderators can add (arma enforces the
  # same "moderator" access in ESMs_command_add); builders and non-members don't. A visibility guard only -
  # arma remains the authority, so a bypassed request still gets rejected.
  #
  # Territory-admin rights are a request-level fact, so they arrive as an argument rather than being asked for here.
  def territory_addable_by?(territory, steam_uid, admin: false)
    return false if steam_uid.blank?
    return true if admin

    [territory.owner, *territory.moderators].compact.any? { |member| member.steam_uid == steam_uid }
  end

  # A labeled group of territory members (an array of Territory::Member). Renders
  # nothing when the group is empty, so an owner-only territory shows just the
  # owner. territory_id + server_public_id thread down so each row can post its
  # promote/demote/remove action; the member list only lives in the modal, so
  # surface defaults there.
  def territory_member_group(label, members, icon:, territory_id:, server_public_id:, color: "text-info", wrapper_class: "mb-3", surface: "modal")
    return if members.blank?

    tag.div(class: wrapper_class) do
      safe_join([
        tag.div(class: "small fw-semibold mb-2 d-flex align-items-center gap-1") do
          safe_join([tag.i(class: "bi bi-#{icon} #{color}"), tag.span(label)])
        end,
        tag.div(class: "d-flex flex-column gap-1") do
          safe_join(members.map { |member| territory_member_row(member, territory_id:, server_public_id:, surface:) })
        end
      ])
    end
  end

  # DOM id for a territory command's action region. The command name and surface
  # together keep the card and modal buttons for the same territory distinct so a
  # turbo replace targets only one of them. target_uid disambiguates the member
  # actions, which put many regions of the same command in one modal.
  def command_action_id(command_name, territory_id, surface, target_uid = nil)
    [command_name, surface, territory_id, target_uid].compact.join("_")
  end

  # Whether a command renders its in-flight and settled states as an icon-sized
  # control (the member-list actions) rather than a full-width button.
  def territory_command_inline?(command)
    territory_command_copy(command)[:style] == :inline
  end

  # DOM id the action region adopts once a command exists, so the poller and the
  # terminal response both target the same element regardless of which surface
  # the payment was started from.
  def service_command_id(command)
    "service_command_#{command.idempotency_key}"
  end

  # URL the poller watches until the dispatched command settles. The command
  # carries its own server, so a caller holding only the command can still build it.
  def territory_command_status_path(command)
    command_status_server_territories_path(command.server.public_id, command)
  end

  # Confirmation copy for the Pay button. Names the price when the caller knows it
  # (renew_price already carries the "poptabs" label and any tax note); the retry
  # surface has no price to hand, so it falls back to a generic line.
  def pay_confirm_message(renew_price = nil)
    return "Pay #{renew_price} from your locker now?" if renew_price.present?

    "Pay this territory's protection from your locker now?"
  end

  # Button face. Names the price when the caller has it (the modal), so the action
  # states its cost up front; the card has no price to hand and stays generic.
  def pay_button_label(renew_price = nil)
    return "Pay #{renew_price}" if renew_price.present?

    "Pay now"
  end

  # Confirmation copy for the Upgrade button. Names the price when the caller has
  # it (upgrade_price already carries the "poptabs" label and any tax note); the
  # retry surface has no price to hand, so it falls back to a generic line.
  def upgrade_confirm_message(upgrade_price = nil)
    return "Upgrade this territory for #{upgrade_price} from your locker now?" if upgrade_price.present?

    "Upgrade this territory from your locker now?"
  end

  # Button face. Names the target level when the caller has it (the modal's Next
  # level section); the retry surface has no snapshot, so it stays generic. The
  # price already sits in the section stats, so the button doesn't restate it.
  def upgrade_button_label(upgrade_level = nil)
    return "Upgrade to level #{upgrade_level}" if upgrade_level.present?

    "Upgrade now"
  end

  # The payment-due panel: a tinted box whose urgency tone frames the Pay action
  # with context so the button never reads as an orphaned control. Shared by the
  # /me card footer and the modal Payment section.
  def territory_pay_panel(territory, server_public_id:, surface:, renew_price:, locker: nil)
    urgency = territory_payment_urgency(territory)
    tone = urgency[:tone]
    control = territory_pay_control(territory, server_public_id:, surface:, renew_price:, tone:, locker:)
    header_class = class_names("d-flex align-items-center gap-2 fw-semibold text-#{tone}", "mb-2": control.present?)

    tag.div(class: "alert alert-#{tone} border-#{tone} bg-#{tone} bg-opacity-10 mb-0") do
      safe_join([
        tag.div(class: header_class) do
          safe_join([tag.i(class: "bi bi-#{urgency[:icon]}"), tag.span(urgency[:label])])
        end,
        control
      ])
    end
  end

  # The actionable control inside the pay panel: the live Pay button, or a
  # disabled stand-in whose label states why payment is blocked. A stolen card
  # carries no button at all (the Stolen section is the explanation); every other
  # blocked case shows the disabled, reason-labeled button.
  def territory_pay_control(territory, server_public_id:, surface:, renew_price:, tone:, locker:)
    block = territory_pay_block(territory, locker:)

    return "".html_safe if block && territory.stolen? && surface == "card"
    return render("servers/territories/command_blocked", label: block[:label], tone: block[:tone]) if block

    render(
      "servers/territories/pay_button",
      server_public_id:,
      territory_id: territory.id,
      surface:,
      renew_price:,
      tone:
    )
  end

  # The actionable control inside the modal's Next level section: the live Upgrade
  # button, or a disabled stand-in when the territory is stolen (mirrors the pay
  # button, which can't renew a stolen base either). The extension enforces the
  # rest server-side, so no other pre-check is gated here.
  def territory_upgrade_control(territory, server_public_id:)
    return render("servers/territories/command_blocked", label: "Territory stolen!", tone: "danger") if territory.stolen?

    render(
      "servers/territories/upgrade_button",
      server_public_id:,
      territory_id: territory.id,
      surface: "modal",
      upgrade_level: territory.upgrade_level,
      upgrade_price: territory.upgrade_price
    )
  end

  # The blocked Pay button's state ({label:, tone:}), or nil when payment can
  # proceed. A stolen flag reads red; a locker short of the cost reads muted and
  # is only checked where the locker is known, so the modal passes nil and skips
  # the funds check.
  def territory_pay_block(territory, locker:)
    return {label: "Territory stolen!", tone: "danger"} if territory.stolen?
    return if locker.nil? || locker >= territory.renew_cost

    {label: safe_join(["Not enough ", poptab_icon(classes: %w[poptab-icon-inline]), " in locker"]), tone: "secondary"}
  end

  # The retry button mirrors the panel's urgency tone so a failed payment never
  # re-renders as a success-green control. Falls back to amber when the territory
  # snapshot is unavailable (e.g. the lookup came back blank).
  def retry_pay_button_tone(territory)
    return "warning" if territory.nil?

    territory_payment_urgency(territory)[:tone]
  end

  # Urgency mood for the payment panel: two tones keep the visual language simple.
  # Red once it's down to the wire (overdue, today, tomorrow), amber while the due
  # date is merely approaching.
  def territory_payment_urgency(territory)
    days = territory.days_left_until_payment_due

    if days && days <= 1
      {tone: "danger", icon: "exclamation-triangle-fill", label: payment_due_label(days)}
    else
      {tone: "warning", icon: "clock-fill", label: payment_due_label(days)}
    end
  end

  def payment_due_label(days)
    return "Payment due" if days.nil?
    return "Payment overdue" if days.negative?
    return "Payment due today" if days.zero?
    return "Payment due tomorrow" if days == 1

    "Payment due in #{days} days"
  end

  # The compact payment cell for the admin territories list: a days-left label colored on the same thresholds the /me pay
  # panels use (red within 2 days, amber within 5, green beyond). A territory with no payment on record reads muted, with
  # no due date to color.
  def territory_list_payment(territory)
    days = territory.days_left_until_payment_due

    return Datum.new(label: "No payment", css_class: "text-muted") if days.nil?
    return Datum.new(label: "Overdue", css_class: "text-danger") if days.negative?
    return Datum.new(label: "Due today", css_class: "text-danger") if days.zero?

    css_class =
      if days <= 2
        "text-danger"
      elsif days <= 5
        "text-warning"
      else
        "text-success"
      end

    Datum.new(label: "#{pluralize(days, "day")} left", css_class:)
  end

  # What the admin territories list's search box matches against: the name, the id an admin arrives holding, and the
  # owner's name and uid, since "find so-and-so's base" is as common as finding it by its own name.
  def territory_search_terms(territory)
    [territory.name, territory.id, territory.owner.name, territory.owner.steam_uid].join(" ").downcase
  end

  # User-facing reason a restore didn't complete. A timeout is hedged (the in-game side may still have landed); a recorded
  # error_message is the extension's own rejection and is shown verbatim; anything else falls to a generic line.
  def territory_restore_failure_message(command)
    return "The server didn't respond in time. Check in-game before restoring again." if command.timed_out?
    return command.error_message if command.error_message.present?

    "Something went wrong restoring the territory. Please try again."
  end

  # Display copy for a territory command, keyed on its name. Central so the
  # shared _command_* partials never branch on command_name themselves.
  def territory_command_copy(command)
    copy = TERRITORY_COMMAND_COPY.fetch(command.command_name)
    return copy unless copy[:added] && command_added?(command)

    copy.merge(copy[:added])
  end

  # add reports its outcome on the row - a request was sent, or (territory admin / self-add) the player was
  # added straight away. The "added" copy applies only to the latter.
  def command_added?(command)
    command.result.to_h.with_indifferent_access[:outcome].to_s == "added"
  end

  # Label + tone for the in-flight spinner button (e.g. "Paying…" amber,
  # "Upgrading…" green), matching the trigger it replaces.
  def territory_command_processing_label(command)
    territory_command_copy(command)[:progressive]
  end

  def territory_command_processing_tone(command)
    territory_command_copy(command)[:processing_tone]
  end

  # The toast that announces a settled command's outcome.
  def territory_command_outcome_toast(command)
    copy = territory_command_copy(command)
    return create_toast(copy[:success_toast], title: copy[:past_tense], color: "green") if command.completed?

    create_toast(territory_command_failure_message(command), title: copy[:failure_title], color: "red")
  end

  # User-facing reason a command didn't complete. A timeout is deliberately
  # hedged: the in-game side effect may still have happened. A recorded
  # error_message is a business rejection from the extension (e.g. not enough
  # poptabs) and is shown verbatim; anything else fell to the generic catch,
  # which logs instead of recording, so we show a generic line and keep internals
  # off the page.
  def territory_command_failure_message(command)
    copy = territory_command_copy(command)
    return copy[:timeout_failure] if command.timed_out?
    return command.error_message if command.error_message.present?

    copy[:generic_failure]
  end

  # Rebuilds the right trigger after a failed command so a retry re-runs the same
  # action. Dispatches on command_name because each command's button carries its
  # own copy and price; the retry_territory snapshot re-supplies that context so
  # the button isn't priceless. replace_id points the retry at the result region
  # so a fresh attempt clears the previous error rather than nesting under it.
  def territory_command_retry_button(command, retry_territory)
    case command.command_name
    when "pay"
      render "servers/territories/pay_button",
        server_public_id: command.server.public_id,
        territory_id: command.arguments[:territory_id],
        surface: "retry",
        renew_price: retry_territory&.renew_price,
        tone: retry_pay_button_tone(retry_territory),
        replace_id: service_command_id(command)
    when "upgrade"
      render "servers/territories/upgrade_button",
        server_public_id: command.server.public_id,
        territory_id: command.arguments[:territory_id],
        surface: "retry",
        upgrade_level: retry_territory&.upgrade_level,
        upgrade_price: retry_territory&.upgrade_price,
        replace_id: service_command_id(command)
    when "promote", "demote", "remove"
      action = MEMBER_ACTIONS.fetch(command.command_name.to_sym)

      # A retry skips the confirm - the member already agreed to it once, and the
      # failed attempt didn't change anything. The name is gone by now anyway.
      render "servers/territories/member_action_button",
        server_public_id: command.server.public_id,
        territory_id: command.arguments[:territory_id],
        surface: "retry",
        command_name: action[:command_name],
        target_uid: command.arguments[:target],
        icon: action[:icon],
        variant: action[:variant],
        label: action[:label],
        replace_id: service_command_id(command)
    when "set_id"
      # Re-open the editor prefilled with what they typed so a failed rename can
      # be fixed and resubmitted without retyping the id.
      render "servers/territories/set_id",
        server_public_id: command.server.public_id,
        territory_id: command.arguments[:old_territory_id],
        surface: "retry",
        open: true,
        value: command.arguments[:new_territory_id],
        replace_id: service_command_id(command)
    end
  end

  # A member row: a prominent name and a muted, monospace steam uid, trailed by
  # the role's action icons (none for the owner).
  def territory_member_row(member, territory_id:, server_public_id:, surface:)
    tag.div(class: "d-flex align-items-center justify-content-between gap-2") do
      safe_join([
        tag.div(class: "d-flex align-items-baseline gap-2 flex-wrap") do
          safe_join([
            tag.span(member.name, class: "text-body"),
            tag.span(member.steam_uid, class: "small text-secondary-emphasis font-monospace")
          ])
        end,
        territory_member_action_cluster(member, territory_id:, server_public_id:, surface:)
      ])
    end
  end

  # The trailing action icons for a member row, or an empty string when the role
  # has no actions (the owner).
  def territory_member_action_cluster(member, territory_id:, server_public_id:, surface:)
    actions = territory_member_actions(member)
    return "".html_safe if actions.blank?

    tag.div(class: "d-flex align-items-center gap-1 flex-shrink-0") do
      safe_join(
        actions.map do |action|
          render "servers/territories/member_action_button",
            server_public_id:,
            territory_id:,
            surface:,
            command_name: action[:command_name],
            target_uid: member.steam_uid,
            icon: action[:icon],
            variant: action[:variant],
            label: action[:label],
            confirm: action[:confirm]&.call(member)
        end
      )
    end
  end

  # The action specs available for a member, resolved from its role.
  def territory_member_actions(member)
    MEMBER_ROLE_ACTIONS.fetch(member.role, []).filter_map do |action|
      next unless command_accessible?(action)
      next unless viewing_self? || territory_admin?

      MEMBER_ACTIONS.fetch(action)
    end
  end

  # The POST path for a member action, built from the command name via the
  # <command>_member route convention (promote -> promote_member, and so on).
  def territory_member_command_path(command_name, server_public_id, territory_id)
    public_send(:"server_territory_#{command_name}_member_path", server_public_id, territory_id)
  end
end
