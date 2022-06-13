Deface::Override.new(
  virtual_path: "spree/checkout/edit",
  name: "add_paypal_button",
  insert_top: '[data-hook="checkout_form_wrapper"]',
  partial: 'spree/checkout/paypal'
)