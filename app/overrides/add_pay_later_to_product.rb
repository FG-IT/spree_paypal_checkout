Deface::Override.new(
  virtual_path: "spree/products/_cart_form",
  name: "add_pay_later_to_product",
  insert_bottom: 'div#product-price',
  text: <<-EOF
    <% if is_product_available_in_currency && @product.can_supply? && ::Spree::PaypalCheckout.find_available_on_front_end_paypal_checkout_method.present? %>
      <div
        data-pp-message
        data-pp-placement="product"
        data-pp-style-layout="text"
        data-pp-style-text-size="<%= ::Spree::PaypalCheckout.find_available_on_front_end_paypal_checkout_method.preferred_pay_later_text_size %>"
        data-pp-style-logo-type="inline"
        data-pp-style-text-color="black"
        data-pp-amount="<%= default_variant.price_in(current_currency).price_including_vat_for(current_price_options) %>"
      >
      </div>
    <% end %>
  EOF
)