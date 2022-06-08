Spree::Core::Engine.add_routes do
  post '/paypal/create_paypal_order', :to => "paypal#create_paypal_order", :as => :paypal_create_paypal_order
  post '/paypal/add_shipping_address', :to => "paypal#add_shipping_address", :as => :paypal_add_shipping_address
  post '/paypal/get_checkout_summary', :to => "paypal#get_checkout_summary", :as => :paypal_get_checkout_summary

  get '/paypal/confirm', :to => "paypal#confirm", :as => :confirm_paypal
  get '/paypal/cancel', :to => "paypal#cancel", :as => :cancel_paypal
  get '/paypal/notify', :to => "paypal#notify", :as => :notify_paypal

  namespace :admin do
    # Using :only here so it doesn't redraw those routes
    resources :orders, :only => [] do
      resources :payments, :only => [] do
        member do
          get 'paypal_refund'
          post 'paypal_refund'
        end
      end
    end
  end

end
