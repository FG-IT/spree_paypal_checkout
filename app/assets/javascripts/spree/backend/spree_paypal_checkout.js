//= require spree/backend

SpreePaypalCheckout = {
  hideSettings: function(paymentMethod) {
    if (SpreePaypalCheckout.paymentMethodID && paymentMethod.val() == SpreePaypalCheckout.paymentMethodID) {
      $('.payment-method-settings').children().hide();
      $('#payment_amount').prop('disabled', 'disabled');
      $('button[type="submit"]').prop('disabled', 'disabled');
      $('#paypal-warning').show();
    } else if (SpreePaypalCheckout.paymentMethodID) {
      $('.payment-method-settings').children().show();
      $('button[type=submit]').prop('disabled', '');
      $('#payment_amount').prop('disabled', '')
      $('#paypal-warning').hide();
    }
  }
}

$(document).ready(function() {
  checkedPaymentMethod = $('[data-hook="payment_method_field"] input[type="radio"]:checked');
  SpreePaypalCheckout.hideSettings(checkedPaymentMethod);
  paymentMethods = $('[data-hook="payment_method_field"] input[type="radio"]').click(function (e) {
    SpreePaypalCheckout.hideSettings($(e.target));
  });
})
