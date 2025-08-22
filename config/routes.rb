Rails.application.routes.draw do

  mount API::Base, at: "/"

  authenticate :user do
    mount_avo
    mount GoodJob::Engine => 'good_job'
  end
  

  devise_for :users, controllers: {
    omniauth_callbacks: 'users/omniauth_callbacks', skip: [:registrations]
  }

  root "home#index"

  resources :articles
  resource :user, only: %i[edit update destroy]
  resources :users, only: %i[index show]

  get "/pages/:page" => "pages#show", as: :page

  match '/404', to: 'errors#not_found', via: :all
  match '/422', to: 'errors#internal_server_error', via: :all
  match '/500', to: 'errors#internal_server_error', via: :all
end
