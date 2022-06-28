Deface::Override.new(
  virtual_path: "spree/products/_cart_form",
  name: "add_pay_later_to_product",
  insert_bottom: 'div#product-price',
  text: <<-EOF
    <% if is_product_available_in_currency && @product.can_supply? && ::Spree::PaypalCheckout.find_available_on_front_end.present? %>
      <%= render partial: "spree/shared/paypal_checkout_pay_later", locals: {amount: default_variant.price_in(current_currency).price_including_vat_for(current_price_options)} %>
      <%= render partial: "spree/shared/paypal_checkout_js_sdk" %>
    <% end %>
  EOF
)