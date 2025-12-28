Rails.application.routes.draw do
#  mount Motor::Admin => '/motor_admin'

  mount API::Base, at: "/"

  authenticate :user do
    mount_avo
    mount GoodJob::Engine => 'good_job'
  end
  

  devise_for :users,
     controllers: { omniauth_callbacks: 'users/omniauth_callbacks' },
     skip: [:registrations]

  root "home#index"

  resources :articles
  
  resources :movies, only: %i[index show]

  resource :user, only: %i[edit update destroy]
  resources :users, only: %i[index show]

  get "/pages/:page" => "pages#show", as: :page

  get '/auth/google', to: 'google_auth#authorize'
  get '/oauth2callback', to: 'google_auth#callback'


  match '/404', to: 'errors#not_found', via: :all
  match '/422', to: 'errors#internal_server_error', via: :all
  match '/500', to: 'errors#internal_server_error', via: :all
end

if defined? ::Avo
  Avo::Engine.routes.draw do
    # This route is not protected, secure it with authentication if needed.
    get "dashboard", to: "tools#dashboard", as: :dashboard
  end
end

if defined? ::Avo
  Avo::Engine.routes.draw do
    # This route is not protected, secure it with authentication if needed.
    get "temperature_dashboard", to: "tools#temperature_dashboard", as: :temperature_dashboard
  end
end
