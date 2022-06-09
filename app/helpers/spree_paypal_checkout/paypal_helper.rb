module SpreePaypalCheckout
  def paypal_express_id
    PaymentMethod.find_by(type: "Spree::Gateway::Paypal").id
  end
end