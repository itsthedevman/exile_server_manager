# frozen_string_literal: true

class RequestsController < AuthenticatedController
  def accept
    request = current_user.pending_requests.find_by(uuid: params[:id])
    return render :not_found if request.nil?

    if ESM.bot.accept_request(request.id)
      render :success, locals: {verb: "accepted"}
    else
      render :failure, locals: {verb: "accept", request: request}
    end
  end

  def decline
    request = current_user.pending_requests.find_by(uuid: params[:id])
    return render :not_found if request.nil?

    if ESM.bot.decline_request(request.id)
      render :success, locals: {verb: "declined"}
    else
      render :failure, locals: {verb: "decline", request: request}
    end
  end
end
