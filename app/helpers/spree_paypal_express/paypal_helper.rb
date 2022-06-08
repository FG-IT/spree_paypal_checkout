module SpreePaypalExpress
  def paypal_express_id
    PaymentMethod.find_by(type: "Spree::Gateway::PayPalExpress").id
  end
end