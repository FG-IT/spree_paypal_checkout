Deface::Override.new(
  virtual_path: "spree/admin/orders/_payments",
  name: "add_capture_due",
  insert_bottom: 'div.outstanding-balance',
  text: <<-EOF
    <% if @order.paypal_checkout.state == 'AUTHORIZED' %>
      <%= Spree.t('paypal.canpture_due', due_time: @order.paypal_checkout.order_valid_time.strftime('%a, %d %b %Y %H:%M:%S')).html_safe %>
    <% end %>
  EOF
)