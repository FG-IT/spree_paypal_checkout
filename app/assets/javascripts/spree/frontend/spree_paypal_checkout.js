//= require spree/frontend
var checkoutText = ''
SpreePaypalCheckout = {
  updateSaveAndContinueVisibility: function () {
    if (this.isButtonHidden()) {
      $(this).trigger('hideSaveAndContinue')
    } else {
      $(this).trigger('showSaveAndContinue')
    }
  },
  isButtonHidden: function () {
    paymentMethod = this.checkedPaymentMethod();
    return (SpreePaypalCheckout.paymentMethodID && paymentMethod.val() === SpreePaypalCheckout.paymentMethodID);
  },
  checkedPaymentMethod: function () {
    return $('div[data-hook="checkout_payment_step"] input[type="radio"][name="order[payments_attributes][][payment_method_id]"]:checked');
  },
  hideSaveAndContinue: function () {
    if (checkoutText == '') {
      checkoutText = $("#checkout_form_payment [data-hook=buttons] .checkout-content-save-continue-button").val()
    }
    $("#checkout_form_payment [data-hook=buttons] .checkout-content-save-continue-button").html('Complete order');
    $("#checkout_form_payment [data-hook=buttons] .checkout-content-save-continue-button").val('Complete order');
  },
  showSaveAndContinue: function () {
    if (checkoutText != '') {
      $("#checkout_form_payment [data-hook=buttons] .checkout-content-save-continue-button").html(checkoutText);
      $("#checkout_form_payment [data-hook=buttons] .checkout-content-save-continue-button").val(checkoutText);
    }
  }
}

document.addEventListener('turbolinks:load', function () {
  SpreePaypalCheckout.updateSaveAndContinueVisibility();
  paymentMethods = $('div[data-hook="checkout_payment_step"] input[type="radio"]').click(function (e) {
    SpreePaypalCheckout.updateSaveAndContinueVisibility();
  });
  var paypal_logo_tag = $('#paypal-image-logo')
  $('div[data-hook="checkout_payment_step"] .payment-option').each(function () {
    var radio = $(this).find('input[type="radio"][name="order[payments_attributes][][payment_method_id]')
    if (radio.attr('value') == SpreePaypalCheckout.paymentMethodID) {
      $(this).find('.spree-radio-label-text').html(paypal_logo_tag.html())
    }
  })
  $('#checkout_form_payment').submit(function () {
    $("#checkout_form_payment [data-hook=buttons] .checkout-content-save-continue-button").attr('disabled', 'disabled')
    var paymentMethod = SpreePaypalCheckout.checkedPaymentMethod();
    if (SpreePaypalCheckout.paymentMethodID && SpreePaypalCheckout.paymentMethodID == paymentMethod.val()) {
      let order_id = $("#checkout_form_payment form").attr("id").split("_").pop()

      formData = {
        "paypal_action": "PAY_NOW",
        "order_id": order_id
      }

      fetch("/paypal_checkout/create_paypal_order", {
        method: 'POST',
        headers: {
          'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content'),
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(formData)
      }).then(response => response.json())
      .then((data) => {
        window.location.replace(data.redirect)
        }
      );
      return false
    }
  })
})

paypal
  .Buttons({
    // Sets up the transaction when a payment button is clicked
    style: {
      layout: 'horizontal',
      color:  'gold',
      shape:  'rect',
      label:  'paypal',
      tagline: false
    },
    createOrder: function (data, actions) {
      let order_id = $("#checkout_form_address form").attr("id").split("_").pop()
      
      formData = {
        "paypal_action": "CONTINUE",
        "order_id": order_id
      }

      return fetch("/paypal_checkout/create_paypal_order", {
        method: 'POST',
        headers: {
          'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content'),
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(formData)
      }).then(response => response.json())
        .then((data) => data.token);
    },
    // Finalize the transaction after payer approval
    onApprove: function (data, actions) {
      let order_id = $("#checkout_form_address form").attr("id").split("_").pop()
      paypalOrderData = {
        "data": data,
        "order_id": order_id
      }
      fetch("/paypal_checkout/add_shipping_address", {
        method: 'POST',
        headers: {
          'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content'),
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(paypalOrderData)
      }).then(response => response.json())
        .then((data) => {
          window.location.href =  data.redirect
        })
    }
  })
  .render("#paypal-button-container");