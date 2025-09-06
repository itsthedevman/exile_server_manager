# frozen_string_literal: true

Rails.application.routes.draw do
  # Devise shit
  devise_for :users, class_name: "ESM::User", controllers: {omniauth_callbacks: "oauth"}
  devise_scope :user do
    # /login
    get :login, to: "oauth#login"

    # /logout
    delete :logout, to: "devise/sessions#destroy", as: :logout
  end

  direct :discord_markdown_docs do
    "https://support.discord.com/hc/en-us/articles/210298617-Markdown-Text-101-Chat-Formatting-Bold-Italic-Underline"
  end

  # Legacy Redirects
  get "/portal/server", to: redirect("/communities")
  get "player_dashboard", to: redirect("/account")
  get "server_dashboard", to: redirect("/communities")

  ##################################################################################################

  # /
  root "home#index"

  # /account
  resource :users, only: %i[edit update destroy], path: "account" do
    collection do
      get :deregister
      patch :transfer
    end

    # /account/notification_routes
    resources :notification_routes,
      controller: "users/notification_routes",
      only: %i[index create update destroy] do
      collection do
        delete :destroy_many
      end
    end
  end

  # /api
  namespace :api do
    # /api/v1
    scope :v1 do
      # /api/v1/users?discord_ids=IDS
      match "users", to: "users#index", via: [:get, :post]

      # /api/v1/users/:id
      resources :users, only: [:show]
    end
  end

  # /communities
  resources :communities, param: :community_id do
    # /communities/:community_id/channels
    resources :channels, only: %i[index], param: :channel_id

    # /communities/:community_id/commands
    resources :commands, only: %i[index update], param: :name

    # /communities/:community_id/logs/:log_id
    resources :logs, only: [:show], param: :log_id do
      resources :entries, controller: :log_entries, only: [:show], param: :entry_id
    end

    # /communities/:community_id/notifications
    resources :notifications, param: :notification_id, except: [:show]

    # /communities/:community_id/servers
    resources :servers, param: :server_id do
      member do
        get :key # V1
        get :server_config
        get :server_token
        patch :disable_v2
        patch :enable_v2
      end
    end

    # /communities/:community_id/notification_routes
    resources :notification_routes,
      controller: "communities/notification_routes",
      only: %i[index update destroy] do
      collection do
        patch :accept
        patch :decline

        delete :destroy_many
      end
    end
  end

  # /discover
  resource :discover, only: [:show]

  # /docs
  resources :docs, only: [] do
    collection do
      get :commands
      get :getting_started
      get :player_setup
      get :server_setup
    end
  end

  # /downloads/classic
  get "downloads/classic", to: redirect("/downloads/@ESM.zip"), as: :classic_download

  # /downloads/latest
  get(
    "downloads/latest",
    as: :latest_download,
    to: redirect(
      # https://github.com/itsthedevman/esm_arma/releases/download/v2.0.1/@esm-201.zip
      [
        "https://github.com/itsthedevman/esm_arma/releases/download",
        "/v#{ENV["MOD_VERSION"]}",
        "/@esm-#{ENV["MOD_VERSION"].delete(".")}.zip"
      ].join
    )
  )

  # /guides
  resources :guides, only: [] do
    collection do
      get :gambling
      get :player_notifications
      get :server_notifications
    end
  end

  # /invite
  get :invite, to: redirect(ESM.bot.invite_url)

  # /join
  get :join, to: redirect("https://discord.gg/28Ttc2s")

  # /legal
  resource :legal, only: [] do
    collection do
      get :privacy_policy
      get :terms_of_service
    end
  end

  # /register
  get :register, to: redirect("/account/edit")

  # /requests
  resources :requests, only: [] do
    member do
      # /requests/:id/accept
      get "accept"

      # /requests/:id/decline
      get "decline"
    end
  end

  # /tools
  resource :tools, only: [] do
    get :rpt_parser
  end

  # /up
  get :up, to: "rails/health#show", as: :rails_health_check
end
