describe Spree::PaypalCheckoutController do

  # Regression tests for #55
  context "when current_order is nil" do
    before do
      controller.stub :current_order => nil
      controller.stub :current_spree_user => nil
    end

    context "add_shipping_address" do
      it "raises ActiveRecord::RecordNotFound" do
        expect { post :add_shipping_address }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "create_paypal_order" do
      it "raises ActiveRecord::RecordNotFound" do
        expect { post :create_paypal_order }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "confirm" do
      it "raises ActiveRecord::RecordNotFound" do
        expect { get :confirm }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "cancel" do
      it "raises ActiveRecord::RecordNotFound" do
        expect{ get :cancel }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
