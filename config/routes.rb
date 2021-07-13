Rails.application.routes.draw do
  devise_for :users
  resources :pages
  root 'pages#home'
  namespace :stripe do
    resources :checkouts
    post 'webhook' => 'checkouts#webhook'
    get 'cart' => 'checkouts#new'
    get 'finalize', to: 'checkouts#create'
    get 'thanks' => 'checkouts#thanks'
  end
  resources :subscriptions
  resources :charges, 
    only: [:new, :create]
  get 'thanks/join?' => 'charges#thanks'
end