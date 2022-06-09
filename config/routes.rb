Spree::Core::Engine.add_routes do
  post '/paypal_checkout/create_paypal_order', :to => "paypal_checkout#create_paypal_order", :as => :paypal_checkout_create_paypal_order
  post '/paypal_checkout/add_shipping_address', :to => "paypal_checkout#add_shipping_address", :as => :paypal_checkout_add_shipping_address
  post '/paypal_checkout/get_checkout_summary', :to => "paypal_checkout#get_checkout_summary", :as => :paypal_checkout_get_checkout_summary

  get '/paypal_checkout/confirm', :to => "paypal_checkout#confirm", :as => :confirm_paypal_checkout
  get '/paypal_checkout/cancel', :to => "paypal_checkout#cancel", :as => :cancel_paypal_checkout
  get '/paypal_checkout/notify', :to => "paypal_checkout#notify", :as => :notify_paypal_checkout

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
