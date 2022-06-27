# Deface::Override.new(
#   virtual_path: "spree/admin/orders/_payments",
#   name: "add_capture_due",
#   insert_bottom: 'div.outstanding-balance',
#   text: <<-EOF
#     <% if @order.paypal_checkout&.state == 'AUTHORIZED' %>
#       <%= Spree.t('paypal.canpture_due', due_time: @order.paypal_checkout.order_valid_time.strftime('%a, %d %b %Y %H:%M:%S')).html_safe %>
#     <% end %>
#   EOF
# )

Deface::Override.new(
  virtual_path: "spree/admin/payments/_list",
  name: "add_capture_due_time",
  replace: 'td[2]',
  text: <<-EOF
    <td>
      <% if @order.paypal_checkout&.state == 'AUTHORIZED' %>
        <%= Spree.t('paypal.canpture_due', due_time: pretty_time(@order.paypal_checkout.order_valid_time)).html_safe %>
      <% else %>
        <%= pretty_time(payment.created_at) %>
      <% end %>
    </td>
  EOF
)