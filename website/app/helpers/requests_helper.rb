# frozen_string_literal: true

module RequestsHelper
  # Headline for a pending request row. A third-party request (someone adding you to their
  # territory) names the requestor and the ask; a self-request - the confirmation Discord
  # reset/reward/stuck create with `to: yourself` - reads as confirming your own action.
  def request_title(request)
    return "Confirm your #{request.command_name} request" if request_from_self?(request)

    "#{request_requestor_name(request)} wants to #{request_action_phrase(request)}"
  end

  # The specifics under the headline. Only `add` has anything worth spelling out (which
  # territory, on which server); everything else leans on the title alone.
  def request_detail(request)
    return "" unless request.command_name == "add"

    arguments = request.command_arguments || {}
    territory_id = arguments["territory_id"]
    return "" if territory_id.blank?

    server_id = arguments["server_id"]
    safe_join(["Territory ", tag.code(territory_id), server_id.present? ? " on #{server_id}" : ""])
  end

  def request_requestor_name(request)
    request.requestor&.discord_username.presence || "Someone"
  end

  def request_requestor_avatar(request)
    request.requestor&.avatar_url
  end

  private

  def request_from_self?(request)
    request.requestor_user_id == request.requestee_user_id
  end

  def request_action_phrase(request)
    case request.command_name
    when "add" then "add you to a territory"
    else "run #{request.command_name}"
    end
  end
end
