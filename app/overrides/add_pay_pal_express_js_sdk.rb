Deface::Override.new(
  virtual_path: "spree/shared/_head",
  name: "add_paypal_js_sdk_link",
  insert_before: 'meta',
  partial: 'spree/shared/paypal_checkout_js_sdk.js'
)