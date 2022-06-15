require 'paypalhttp'
require './lib/spree_paypal_checkout'

module TestHarness
  class << self
    def environment
      client_id = ENV['PAYPAL_CLIENT_ID'] || 'AUw8RvSkGWFJsNh4rBcCkztSW2ktewEGHWnOzYAB3OhbHzfdYUSBJHIY-Bv65r4Y7Riyj_qaQHt_4Zj0'
      client_secret = ENV['PAYPAL_CLIENT_SECRET'] || 'EKXPsGaFmkeav0P3jAEICnYn8p00fFMSuhcHZ6FRrI25Pl2wvnMme8WRy0AMITjJeSVoLi7Y7dCVX8uM'

      PayPal::SandboxEnvironment.new(client_id, client_secret)
    end

    def client
      PayPal::PayPalHttpClient.new(self.environment)
    end

    def exec(req, body = nil)
      if body
        req.request_body(body)
      end

      client.execute(req)
    end
  end
end
