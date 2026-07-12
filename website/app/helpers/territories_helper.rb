# frozen_string_literal: true

module TerritoriesHelper
  # Per-command display copy for the shared territory-command action flow (the
  # processing spinner, the settled result line, and the outcome toast). Adding a
  # new territory write is one row here plus its trigger partial - the machinery
  # in the _command_* partials is command-agnostic. The error_message branch of a
  # failure is shared (it's the extension's own rejection text), so only the
  # timeout hedge and the generic-catch line are per-command.
  TERRITORY_COMMAND_COPY = {
    "pay" => {
      progressive: "Paying…",
      past_tense: "Paid",
      processing_tone: "warning",
      success_toast: "Territory payment complete.",
      failure_title: "Payment failed",
      timeout_failure: "The server didn't respond in time. Check in-game before paying again.",
      generic_failure: "Something went wrong processing the payment. Please try again."
    },
    "upgrade" => {
      progressive: "Upgrading…",
      past_tense: "Upgraded",
      processing_tone: "success",
      success_toast: "Territory upgraded.",
      failure_title: "Upgrade failed",
      timeout_failure: "The server didn't respond in time. Check in-game before upgrading again.",
      generic_failure: "Something went wrong processing the upgrade. Please try again."
    }
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
  def territory_stat(label, value, color: nil)
    tag.div(class: "col-6 col-md-4") do
      safe_join([
        tag.div(label, class: "text-secondary-emphasis small text-uppercase mb-1"),
        tag.div(value, class: class_names("fs-5 fw-semibold text-break", color))
      ])
    end
  end

  # Stolen / Secure pill, matching the territory card.
  def territory_flag_badge(territory)
    if territory.stolen?
      tag.span(class: "badge bg-danger") do
        safe_join([tag.i(class: "bi bi-exclamation-triangle-fill me-1"), "Stolen"])
      end
    else
      tag.span("Secure", class: "badge bg-success")
    end
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

  # A labeled group of territory members (an array of Territory::Member). Renders
  # nothing when the group is empty, so an owner-only territory shows just the
  # owner.
  def territory_member_group(label, members, icon:, color: "text-info", wrapper_class: "mb-3")
    return if members.blank?

    tag.div(class: wrapper_class) do
      safe_join([
        tag.div(class: "small fw-semibold mb-2 d-flex align-items-center gap-1") do
          safe_join([tag.i(class: "bi bi-#{icon} #{color}"), tag.span(label)])
        end,
        tag.div(class: "d-flex flex-column gap-1") do
          safe_join(members.map { |member| territory_member_row(member) })
        end
      ])
    end
  end

  # DOM id for a territory command's action region. The command name and surface
  # together keep the card and modal buttons for the same territory distinct so a
  # turbo replace targets only one of them.
  def command_action_id(command_name, territory_id, surface)
    "#{command_name}_#{surface}_#{territory_id}"
  end

  # DOM id the action region adopts once a command exists, so the poller and the
  # terminal response both target the same element regardless of which surface
  # the payment was started from.
  def server_command_id(command)
    "server_command_#{command.idempotency_key}"
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

  # Display copy for a territory command, keyed on its name. Central so the
  # shared _command_* partials never branch on command_name themselves.
  def territory_command_copy(command)
    TERRITORY_COMMAND_COPY.fetch(command.command_name)
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
        replace_id: server_command_id(command)
    when "upgrade"
      render "servers/territories/upgrade_button",
        server_public_id: command.server.public_id,
        territory_id: command.arguments[:territory_id],
        surface: "retry",
        upgrade_level: retry_territory&.upgrade_level,
        upgrade_price: retry_territory&.upgrade_price,
        replace_id: server_command_id(command)
    end
  end

  # A member row: a prominent name and a muted, monospace steam uid.
  def territory_member_row(member)
    tag.div(class: "d-flex align-items-baseline gap-2 flex-wrap") do
      safe_join([
        tag.span(member.name, class: "text-body"),
        tag.span(member.steam_uid, class: "small text-secondary-emphasis font-monospace")
      ])
    end
  end
end
