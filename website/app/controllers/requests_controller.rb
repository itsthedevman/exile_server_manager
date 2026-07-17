# frozen_string_literal: true

class RequestsController < AuthenticatedController
  def accept
    request = current_user.pending_requests.find_by(uuid: params[:id])
    return render :not_found if request.nil?

    request.accept
    render :success, locals: {verb: "accepted"}
  end

  def decline
    request = current_user.pending_requests.find_by(uuid: params[:id])
    return render :not_found if request.nil?

    request.decline
    render :success, locals: {verb: "declined"}
  end
end
