class Stripe::CheckoutsController < ApplicationController
  before_action :get_cart_overview
  before_action :amount_to_be_charged
  before_action :authenticate_user!

  def new
  end

  def create
    if current_user.stripe_id?
      customer = Stripe::Customer.retrieve(current_user.stripe_id)
    else
      customer = StripeTool.create_customer(
        email: current_user.email, 
        stripe_token: params[:stripeToken]
      )
      current_user.update!(stripe_id: customer.id)
    end
    
    session = Stripe::Checkout::Session.create({
      payment_method_types: ['card'],
      line_items: @line_items,
      customer: customer.id,
      client_reference_id: current_user.id,
      mode: 'payment',
      success_url: "#{stripe_thanks_url}?session_id={CHECKOUT_SESSION_ID}",
      cancel_url: root_url
    })
    
      
    redirect_to session.url
  end
 
  def thanks
    flash[:success] = "You did it!"
  end
    
  def webhook
    sig_header = request.env['HTTP_STRIPE_SIGNATURE']

    begin
      event = Stripe::Webhook.construct_event(request.body.read, sig_header, ENV['STRIPE_ENDPOINT_SECRET'])
    rescue JSON::ParserError
      return head :bad_request
    rescue Stripe::SignatureVerificationError
      return head :bad_request
    end

    webhook_checkout_session_completed(event) if event['type'] == 'checkout.session.completed'

    head :ok
  end

  def interrupt
    current_user.subscription.interrupt
  end
    
  def edit
    session = Stripe::Checkout::Session.create(
      payment_method_types: ['card'],
      mode: 'setup',
      setup_intent_data: {
        metadata: {
          customer_id: current_user.stripe_id,
        },
      },
      customer_email: current_user.email,
      success_url: CGI.unescape(subscription_url(
        session_id: '{CHECKOUT_SESSION_ID}')
      ),
      cancel_url: subscription_url
    )
    render json: { session_id: session.id }
  end

  private 

  def get_cart_overview
    @line_items = [{
      price_data: {
        unit_amount: 200,
        currency: 'usd',
        product_data: {
          name: 'Double oreo cookie',
          images: ['https://relles-cookies.herokuapp.com/assets/cookie_4-88a00bb8667937eaeb01f135636549549eec017b60ce4f920f7caebe788ad725.jpg']
        },
      },
      quantity: 6
    }, {
      price_data: {
        unit_amount: 150,
        currency: 'usd',
        product_data: {
          name: 'Pink chip cookie',
          images: ['http://relles-cookies.herokuapp.com/assets/pink-chip-aa0b6c5e00e6bc6c156d1cf9efcf1823785c4117ed2d045c893331b07df4598d.png']
        },
      },
      quantity: 6
    }]
  end

  def amount_to_be_charged
    @amount = 0
    @line_items.each do |item|
      @amount += item[:price_data][:unit_amount] * item[:quantity]
    end
  end

  def build_subscription(stripe_subscription)
    Subscription.new(plan_id: stripe_subscription.plan.id,
                     stripe_id: stripe_subscription.id,
                     current_period_ends_at: Time.zone.at(stripe_subscription.current_period_end))
  end

  def webhook_checkout_session_completed(event)
    object = event['data']['object']
    customer = Stripe::Customer.retrieve(object['customer'])
    #stripe_subscription = Stripe::Subscription.retrieve(object['subscription'])
    #subscription = build_subscription(stripe_subscription)
    user = User.find_by(id: object['client_reference_id'])
    #user.subscription.interrupt if user.subscription.present?
    user.update!(stripe_id: customer.id)
  end
end
