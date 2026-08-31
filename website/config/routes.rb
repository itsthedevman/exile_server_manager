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

    # /account/requests
    resources :requests, controller: "users/requests", only: %i[index] do
      member do
        # /account/requests/:id/accept
        post :accept

        # /account/requests/:id/decline
        post :decline
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
    member do
      get :available
    end

    # /communities/:community_id/change_mode
    resource :change_mode, only: [:update], controller: "communities/modes"

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
    resources :servers, param: :server_id, controller: "communities/servers" do
      collection do
        get :available
      end

      member do
        get :key # V1
        get :server_config
        get :server_token
        patch :disable_v2
        patch :enable_v2
        get :available
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

    if Rails.env.local?
      # /communities/:community_id/broadcast
      resource :broadcast, only: [:create], controller: "communities/broadcasts" do
        collection do
          # /communities/:community_id/broadcast/commands/:command_id/status
          get "commands/:command_id/status", action: :status, as: :command_status
        end
      end

      # /communities/:community_id/cooldowns
      resources :cooldowns, only: [:index], controller: "communities/cooldowns" do
        collection do
          # /communities/:community_id/cooldowns/clear
          post :clear

          # /communities/:community_id/cooldowns/commands/:command_id/status
          get "commands/:command_id/status", action: :status, as: :command_status
        end
      end
    end
  end

  if Rails.env.local?
    # /dev/login/:discord_id
    # Signs in as an existing user so local browsing and browser-driven tests skip Discord OAuth.
    get "dev/login/:discord_id", to: "dev/sessions#create", as: :dev_login
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
      # https://github.com/itsthedevman/exile_server_manager/releases/download/arma/vX.Y.Z/@esm-201.zip
      [
        "https://github.com/itsthedevman/exile_server_manager/releases/download",
        "/arma/v#{Settings.mod_version}",
        "/@esm-#{Settings.mod_version.delete(".")}.zip"
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

  if Rails.env.local?
    # /servers/:id
    resources :servers, only: [:show] do
      # /servers/:id/live
      member do
        get :live
      end

      # /servers/:server_id/players
      resources :players, controller: "servers/players", only: [:index, :show], param: :uid do
        collection do
          # /servers/:server_id/players/me
          get :me

          # /servers/:server_id/players/summary
          get :summary

          # /servers/:server_id/players/list
          get :list

          # /servers/:server_id/players/lookup
          get :lookup

          # /servers/:server_id/players/reset_me
          post :reset_me

          # /servers/:server_id/players/reset_all
          post :reset_all

          # /servers/:server_id/players/commands/:command_id/status
          get "commands/:command_id/status", action: :status, as: :command_status
        end

        member do
          # /servers/:server_id/players/:uid/reset
          post :reset

          # /servers/:server_id/players/:uid/modify
          post :modify
        end
      end

      # /servers/:server_id/territories
      resources :territories, controller: "servers/territories", only: [:index, :show], param: :territory_id do
        # /servers/:server_id/territories/:territory_id/restore
        post :restore

        # /servers/:server_id/territories/:territory_id/pay
        post :pay

        # /servers/:server_id/territories/:territory_id/upgrade
        post :upgrade

        # /servers/:server_id/territories/:territory_id/add_member
        post :add_member

        # /servers/:server_id/territories/:territory_id/promote_member
        post :promote_member

        # /servers/:server_id/territories/:territory_id/remove_member
        post :remove_member

        # /servers/:server_id/territories/:territory_id/demote_member
        post :demote_member

        # /servers/:server_id/territories/:territory_id/set_id
        post :set_id

        collection do
          # /servers/:server_id/territories/list
          get :list

          # /servers/:server_id/territories/commands/:command_id/status
          get "commands/:command_id/status", action: :status, as: :command_status
        end
      end

      # /servers/:server_id/favorite
      resource :favorite, only: [:create, :destroy], controller: "servers/favorites"

      # /servers/:server_id/gamble
      resource :gamble, only: [:create], controller: "servers/gambling" do
        collection do
          # /servers/:server_id/gamble/commands/:command_id/status
          get "commands/:command_id/status", action: :status, as: :command_status
        end
      end

      # /servers/:server_id/sqf
      resource :sqf, only: [:create], controller: "servers/sqf" do
        collection do
          # /servers/:server_id/sqf/commands/:command_id/status
          get "commands/:command_id/status", action: :status, as: :command_status
        end
      end
    end
  end

  # /tools
  resource :tools, only: [] do
    get :rpt_parser
  end

  # /up
  get :up, to: "rails/health#show", as: :rails_health_check

  ##################################################################################################

  # Legacy Redirects
  get :"tools/id_parser", to: redirect("/discover")
  get :"portal/server", to: redirect("/communities")
  get :player_dashboard, to: redirect("/account")
  get :server_dashboard, to: redirect("/communities")

  get :wiki, to: redirect("/docs/getting_started")

  namespace :wiki do
    get :"api(/:function)", to: redirect("/docs/getting_started")
    get :"changelog(/:date)", to: redirect("/docs/getting_started")
    get :commands, to: redirect("/docs/commands")
    get :gambling, to: redirect("/docs/getting_started")
    get :getting_started_v2, to: redirect("/docs/getting_started")
    get :getting_started, to: redirect("/docs/getting_started")
    get :notification_configuration, to: redirect("/docs/getting_started")
    get :player_mode, to: redirect("/docs/getting_started")
    get :player_xm8_notification_routing, to: redirect("/docs/getting_started")
    get :privacy, to: redirect("/legal/privacy_policy")
    get :server_xm8_notification_routing, to: redirect("/docs/getting_started")
    get :tos, to: redirect("/legal/terms_of_service")
  end
end
