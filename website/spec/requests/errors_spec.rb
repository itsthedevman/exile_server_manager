# frozen_string_literal: true

RSpec.describe "Errors", type: :request do
  describe "ErrorsController#show" do
    it "renders a not found page inside the site layout" do
      get "/404"

      expect(response).to have_http_status(:not_found)
      expect(response.body).to include("404 - Not Found", "has been moved", "navbar")
    end

    it "renders a server error page" do
      get "/503"

      expect(response).to have_http_status(:service_unavailable)
      expect(response.body).to include("503 - Service Unavailable", "Something went wrong on our end")
    end

    it "uses its class's copy for a status that has none of its own" do
      get "/403"

      expect(response).to have_http_status(:forbidden)
      expect(response.body).to include("403 - Forbidden", "Check the address and try again")
    end

    it "answers a JSON request with JSON" do
      get "/404.json"

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body).to eq("error" => "Not Found")
    end

    it "falls back to the static page when the layout itself cannot render" do
      allow_any_instance_of(ErrorsController).to receive(:current_user)
        .and_raise(ActiveRecord::ConnectionNotEstablished)

      get "/503"

      expect(response).to have_http_status(:service_unavailable)
      expect(response.body).to include("something went wrong")
      expect(response.body).not_to include("navbar")
    end
  end

  # The test environment shows detailed exceptions and only rescues some of them, so the exceptions app never runs
  # unless both are switched to what production does.
  describe "as the exceptions app" do
    around do |example|
      env_config = Rails.application.env_config
      original = env_config.slice("action_dispatch.show_exceptions", "action_dispatch.show_detailed_exceptions")

      env_config["action_dispatch.show_exceptions"] = :all
      env_config["action_dispatch.show_detailed_exceptions"] = false
      example.run
    ensure
      env_config.merge!(original)
    end

    it "renders an unrouted path as the site's own 404" do
      get "/this/page/does/not/exist"

      expect(response).to have_http_status(:not_found)
      expect(response.body).to include("404 - Not Found", "navbar")
    end

    it "renders an unexpected exception as the site's own 500" do
      allow_any_instance_of(HomeController).to receive(:index).and_raise("boom")

      get "/"

      expect(response).to have_http_status(:internal_server_error)
      expect(response.body).to include("500 - Internal Server Error", "navbar")
    end
  end

  describe "a controller raising NotFoundError" do
    it "renders the same not found page" do
      allow_any_instance_of(HomeController).to receive(:index).and_raise(Exceptions::NotFoundError)

      get "/"

      expect(response).to have_http_status(:not_found)
      expect(response.body).to include("404 - Not Found", "navbar")
    end
  end
end
