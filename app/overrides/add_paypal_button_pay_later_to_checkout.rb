Deface::Override.new(
  virtual_path: "spree/checkout/edit",
  name: "add_paypal_button",
  insert_top: '[data-hook="checkout_form_wrapper"]',
  partial: 'spree/checkout/paypal_checkout'
)

Deface::Override.new(
  virtual_path: "spree/orders/edit",
  name: "add_paypal_pay_later_in_cart",
  insert_after: %Q{erb[loud]:contains("render partial: 'summary'")},
  text: <<-EOF
    <% if ::Spree::PaypalCheckout.find_available_on_front_end.present? %>
      <div id="cart-paypal-pay-later">
        <%= render partial: "spree/shared/paypal_checkout_pay_later", locals: {amount: @order.total} %>
      </div>
      <style>
        #cart-paypal-pay-later {
          margin-top: 0.5em;
        }
      </style>
    <% end %>
  EOF
)

Deface::Override.new(
  virtual_path: "spree/orders/edit",
  name: "add_paypal_button_in_cart",
  insert_before: '[data-hook="cart_buttons"]',
  partial: 'spree/checkout/cart_paypal_checkout_button'
)