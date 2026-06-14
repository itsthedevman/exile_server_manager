# frozen_string_literal: true

module TerritoriesHelper
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

  # A labeled member list. Territory#owner is a single "Name (uid)" string while
  # #moderators / #builders are newline-joined lists; both split cleanly here.
  # Renders nothing when no one qualifies.
  def territory_member_group(label, value, icon:, color: "text-info", wrapper_class: "mb-3")
    members = value.to_s.split("\n").map(&:strip).reject(&:blank?)
    return if members.empty?

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

  # DOM id for a pay action region. `surface` keeps the card and modal buttons
  # for the same territory distinct so a turbo replace targets only one of them.
  def pay_action_id(territory_id, surface)
    "pay_#{surface}_#{territory_id}"
  end

  # DOM id the action region adopts once a command exists, so the poller and the
  # terminal response both target the same element regardless of which surface
  # the payment was started from.
  def server_command_id(command)
    "server_command_#{command.idempotency_key}"
  end

  # The card only carries a Pay button when a payment is actually coming due;
  # mirrors the visibility of #territory_payment_section.
  def territory_payment_due?(territory)
    territory_payment_status(territory).first.present?
  end

  # Confirmation copy for the Pay button. Names the price when the caller knows it
  # (renew_price already carries the "poptabs" label and any tax note); the retry
  # surface has no price to hand, so it falls back to a generic line.
  def pay_confirm_message(renew_price = nil)
    return "Pay #{renew_price} from your locker now?" if renew_price.present?

    "Pay this territory's protection from your locker now?"
  end

  # The toast that announces a settled payment's outcome.
  def pay_outcome_toast(command)
    return create_toast("Territory payment complete.", title: "Paid", color: "green") if command.completed?

    create_toast(pay_failure_message(command), title: "Payment failed", color: "red")
  end

  # User-facing reason a payment didn't complete. A timeout is deliberately
  # hedged: the in-game side effect may still have happened. A recorded
  # error_message is a business rejection from the extension (e.g. not enough
  # poptabs); anything else fell to the generic catch, which logs instead of
  # recording, so we show a generic line and keep internals off the page.
  def pay_failure_message(command)
    return "The server didn't respond in time. Check in-game before paying again." if command.timed_out?
    return web_extension_message(command.error_message, command.user) if command.error_message.present?

    "Something went wrong processing the payment. Please try again."
  end

  # The extension authors player messages for Discord: a leading mention (or, for
  # players with no linked Discord, their Steam UID) plus **bold**/`code` markup.
  # Swap the player token for their name and drop the markup so it reads as plain
  # web copy.
  def web_extension_message(text, user)
    name = user.username.presence || "you"
    tokens = [user.discord_mention, user.steam_uid].compact_blank

    cleaned = tokens.reduce(text) do |message, token|
      message.gsub(token, name)
    end

    cleaned.gsub(/\*\*(.*?)\*\*/, '\1').delete("`").strip
  end

  # Splits a "Name (uid)" entry into a prominent name and a muted, monospace uid.
  def territory_member_row(member)
    match = member.match(/\A(?<name>.+?)\s*\((?<uid>\d+)\)\z/)
    name = match ? match[:name] : member
    uid = match && match[:uid]

    tag.div(class: "d-flex align-items-baseline gap-2 flex-wrap") do
      safe_join([
        tag.span(name, class: "text-body"),
        (tag.span(uid, class: "small text-secondary-emphasis font-monospace") if uid)
      ].compact)
    end
  end
end
