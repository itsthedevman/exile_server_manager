# frozen_string_literal: true

module Users
  class RequestsController < AuthenticatedController
    def index
      render locals: {requests: pending_requests}
    end

    def accept
      respond_to_request(:accept, past_tense: "accepted")
    end

    def decline
      respond_to_request(:decline, past_tense: "declined")
    end

    private

    def pending_requests
      current_user.pending_requests.pending.includes(:requestor).order(created_at: :desc)
    end

    def respond_to_request(action, past_tense:)
      request = current_user.pending_requests.pending.find_by(uuid: params[:id])
      return render turbo_stream: create_error_toast("That request is no longer available.") if request.nil?

      # accept/decline return the bot handler's result (falsy on a successful decline), not a
      # success flag - a genuine failure raises at the NATS boundary, handled like any other action.
      request.public_send(action)

      render turbo_stream: [
        turbo_stream.remove(helpers.dom_id(request)),
        create_success_toast("Request #{past_tense}.")
      ]
    end
  end
end
