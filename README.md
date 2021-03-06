# SpreePaypalCheckout

Introduction goes here.

## Installation

1. Add this extension to your Gemfile with this line:

    ```ruby
    gem 'spree_paypal_checkout'
    ```

2. Install the gem using Bundler

    ```ruby
    bundle install
    ```

3. Copy & run migrations

    ```ruby
    bundle exec rails g spree_paypal_checkout:install
    ```

4. Restart your server
If your server was running, restart it so that it can find the assets properly.

5. Add payment method in your admin and choose Spree::Gateway::PayPalCheckout in provider


6. Fill Paypal Client, Paypal Client Secret, Server: live

7. 
    1. Pay Later Text Size: the pay later text size in admin configuration.
    2. PayPal pay later message in product detail page postion: `div#product-price` in `spree/products/_cart_form`
    3. PayPal express buttons in cart postion: front of the `[data-hook="cart_buttons"]` in `spree/orders/edit`
    4. PayPal pay later message in cart postion: after the `<%= render partial: 'summary', locals: {order: @order} %>` in `spree/orders/edit`
    5. PayPal express buttons in address postion: `[data-hook="checkout_form_wrapper"]` in `spree/checkout/edit`

## Testing

First bundle your dependencies, then run `rake`. `rake` will default to building the dummy app if it does not exist, then it will run specs. The dummy app can be regenerated by using `rake test_app`.

```shell
bundle update
bundle exec rake
```

When testing your applications integration with this extension you may use it's factories.
Simply add this require statement to your spec_helper:

```ruby
require 'spree_paypal_checkout/factories'
```


## PayPal Order Type
1. `intent: "CAPTURE", "AUTHORIZE"`
2. `paypal_action: "CONTINUE", "PAY_NOW"`
3. `shipping_preference: "SET_PROVIDED_ADDRESS", "GET_FROM_FILE"`

## Integration Guide 
1. PayPal Express
    1. `post /paypal_checkout/create_paypal_order`
    Request Body
    `{     
        paypal_action: "CONTINUE", 
        shipping_preference: "GET_FROM_FILE",
    }`
    controller will create paypal order and return token(paypal order id). 
    
    2. After user approve
    `post /paypal_checkout/add_shipping_address`
    `params: onApprove -> data`
    retrieve address and other user infomation from data and add them to order then create new `spree_paypal_checkouts` record(`token` is paypal order id). 
    
    
    3. Complete order by paypal
    `post /paypal_checkout/create_paypal_order`
        1. find paypal order by `spree_paypal_checkouts.token(paypal order id)` and update it by final payment total.
        2. create new `spree_payments` 
        3. `order.next` call `Spree::Gateway::PayPalCheckout#purchase/authorize` then update `state`, `transaction_id` of `spree_paypal_checkouts`

2. Pay by PayPal directly
    1. `post /paypal_checkout/create_paypal_order`
    Request Body
    `{
        paypal_action: 'PAY_NOW',
        application_context: {
            return_url: return_url,
            cancel_url: cancel_url,
            user_action: user_action
        }
    }`

    2. After user approve, it will `get /paypal_checkout/confirm`.
        1. create `spree_paypal_checkouts` and `spree_payments` new record. 
        2. `order.next` call `Spree::Gateway::PayPalCheckout#purchase/authorize` then update `state`, `transaction_id` of `spree_paypal_checkouts`
        
## Releasing

```shell
bundle exec gem bump -p -t
bundle exec gem release
```

For more options please see [gem-release REAMDE](https://github.com/svenfuchs/gem-release)

## Contributing

If you'd like to contribute, please take a look at the
[instructions](CONTRIBUTING.md) for installing dependencies and crafting a good
pull request.

Copyright (c) 2022 [name of extension creator], released under the New BSD License
