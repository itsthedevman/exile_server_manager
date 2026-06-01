# frozen_string_literal: true

module TerritoriesHelper
  # A titled section panel inside the territory detail modal body. The header icon
  # carries an accent color so the panels aren't monochrome.
  def territory_section(title, icon:, color: "text-info", &block)
    tag.div(class: "bg-body-tertiary rounded-3 p-3 mb-3") do
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

  # A labeled member list. Territory#owner is a single "Name (uid)" string while
  # #moderators / #builders are newline-joined lists; both split cleanly here.
  # Renders nothing when no one qualifies.
  def territory_member_group(label, value, icon:, color: "text-info")
    members = value.to_s.split("\n").map(&:strip).reject(&:blank?)
    return if members.empty?

    tag.div(class: "mb-3") do
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
