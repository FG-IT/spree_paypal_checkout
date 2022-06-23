Deface::Override.new(
  virtual_path: "spree/products/_cart_form",
  name: "add_pay_later_to_product",
  insert_bottom: 'div#inside-product-cart-form',
  text: <<-EOF
    <% if is_product_available_in_currency && @product.can_supply? %>
      <div
        data-pp-message
        data-pp-style-layout="text"
        data-pp-style-logo-type="inline"
        data-pp-style-text-color="black"
        data-pp-amount="<%= default_variant.price_in(current_currency).price_including_vat_for(current_price_options) %>"
      >
      </div>
    <% end %>
  EOF
)