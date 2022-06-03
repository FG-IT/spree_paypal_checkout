module Spree
  class Gateway::PayPalExpress < Gateway
    


  def supports?(source)
    true
  end

  def method_type
    'paypal'
  end

  def provider_class
  end

  def provider
  end

  def client
    ::PayPal::PayPalHttpClient.new(environment)
  end

  def environment
    
  end

  def authorize(amount, express_checkout, gateway_options = {})
  end

  def settle(amount, checkout, _gateway_options) end

  def capture(credit_cents, transaction_id, _gateway_options)

  end

  def purchase(amount, express_checkout, gateway_options = {})

  end

  def credit(credit_cents, transaction_id, _options)
    
  end

  def cancel(response_code, _source, payment)
  
  end

  def void(response_code, _source, gateway_options)

  end

  def refund(transaction_id, payment, credit_cents)

  end

  private
  
  def sale(amount, express_checkout, payment_action, gateway_options = {})
    
  end

end