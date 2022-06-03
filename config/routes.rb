Spree::Core::Engine.add_routes do
  post '/paypal/create_paypal_order', :to => "paypal#create_paypal_order", :as => :paypal_create_paypal_order
  post '/paypal/add_shipping_address', :to => "paypal#add_shipping_address", :as => :paypal_add_shipping_address
  post '/paypal/get_checkout_summary', :to => "paypal#get_checkout_summary", :as => :paypal_get_checkout_summary
end
