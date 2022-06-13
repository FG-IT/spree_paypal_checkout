module PaypalServices
  class Request
    class << self
      def request_paypal(provider, request, body=nil)
        request.headers["prefer"] = "return=representation"
        request.request_body(body) if body.present?
        response = provider.execute(request)
        ::PaypalServices::Response.new(response)
      end
    end
  end
end