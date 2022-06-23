Deface::Override.new(
  virtual_path: "spree/checkout/edit",
  name: "add_paypal_button",
  insert_top: '[data-hook="checkout_form_wrapper"]',
  partial: 'spree/checkout/paypal'
)

Deface::Override.new(
  virtual_path: "spree/orders/edit",
  name: "add_paypal_button_under_checkout",
  insert_bottom: 'div.checkout-summary-container',
  partial: 'spree/checkout/paypal_under_checkout'
)