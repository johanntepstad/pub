# frozen_string_literal: true

module NorwegianCompliance
  # VIPPS payment integration with BankID authentication
  class VippsPaymentService
    include HTTParty
    
    base_uri ENV.fetch("VIPPS_API_URL", "https://apitest.vipps.no")
    
    attr_reader :merchant_serial_number, :subscription_key, :access_token

    def initialize
      @merchant_serial_number = Rails.application.credentials.vipps_merchant_serial_number
      @subscription_key = Rails.application.credentials.vipps_subscription_key
      @client_id = Rails.application.credentials.vipps_client_id
      @client_secret = Rails.application.credentials.vipps_client_secret
      @access_token = nil
      @token_expires_at = nil
    end

    # Initialize payment with BankID verification
    def initiate_payment(amount:, customer_phone:, order_id:, callback_url:, fallback_url:)
      ensure_valid_token
      
      payment_request = {
        merchantInfo: {
          merchantSerialNumber: @merchant_serial_number,
          callbackPrefix: callback_url,
          fallbackUrl: fallback_url,
          consentRemovalPrefix: "#{callback_url}/consent-removal"
        },
        customerInfo: {
          mobileNumber: normalize_phone_number(customer_phone)
        },
        transaction: {
          amount: (amount.to_f * 100).to_i, # Convert to øre
          transactionText: "Healthcare Payment - Public Health Platform",
          orderId: order_id,
          skipLandingPage: false,
          scope: "address name email phoneNumber birthDate"
        }
      }

      response = self.class.post(
        "/ecomm/v2/payments",
        headers: vipps_headers,
        body: payment_request.to_json
      )

      handle_vipps_response(response)
    end

    # Get payment status with BankID verification status
    def get_payment_status(order_id)
      ensure_valid_token
      
      response = self.class.get(
        "/ecomm/v2/payments/#{order_id}/details",
        headers: vipps_headers
      )

      result = handle_vipps_response(response)
      
      # Add BankID verification status
      if result[:success] && result[:data]["userDetails"]
        result[:bankid_verified] = verify_bankid_status(result[:data]["userDetails"])
      end

      result
    end

    # Capture authorized payment
    def capture_payment(order_id, amount: nil, transaction_text: nil)
      ensure_valid_token
      
      capture_request = {
        merchantInfo: {
          merchantSerialNumber: @merchant_serial_number
        },
        transaction: {
          transactionText: transaction_text || "Healthcare Service Completed"
        }
      }
      
      capture_request[:transaction][:amount] = (amount.to_f * 100).to_i if amount

      response = self.class.post(
        "/ecomm/v2/payments/#{order_id}/capture",
        headers: vipps_headers,
        body: capture_request.to_json
      )

      handle_vipps_response(response)
    end

    # Cancel payment
    def cancel_payment(order_id, transaction_text: nil)
      ensure_valid_token
      
      cancel_request = {
        merchantInfo: {
          merchantSerialNumber: @merchant_serial_number
        },
        transaction: {
          transactionText: transaction_text || "Healthcare Payment Cancelled"
        }
      }

      response = self.class.put(
        "/ecomm/v2/payments/#{order_id}/cancel",
        headers: vipps_headers,
        body: cancel_request.to_json
      )

      handle_vipps_response(response)
    end

    # Refund payment
    def refund_payment(order_id, amount:, transaction_text: nil)
      ensure_valid_token
      
      refund_request = {
        merchantInfo: {
          merchantSerialNumber: @merchant_serial_number
        },
        transaction: {
          amount: (amount.to_f * 100).to_i,
          transactionText: transaction_text || "Healthcare Payment Refund"
        }
      }

      response = self.class.post(
        "/ecomm/v2/payments/#{order_id}/refund",
        headers: vipps_headers,
        body: refund_request.to_json
      )

      handle_vipps_response(response)
    end

    # Health check for VIPPS service
    def health_check
      begin
        ensure_valid_token
        {
          status: "healthy",
          token_valid: !@access_token.nil?,
          api_accessible: true,
          timestamp: Time.current.iso8601
        }
      rescue StandardError => e
        {
          status: "unhealthy",
          error: e.message,
          timestamp: Time.current.iso8601
        }
      end
    end

    private

    def ensure_valid_token
      if @access_token.nil? || token_expired?
        authenticate
      end
    end

    def token_expired?
      @token_expires_at.nil? || Time.current >= @token_expires_at
    end

    def authenticate
      auth_request = {
        client_id: @client_id,
        client_secret: @client_secret,
        grant_type: "client_credentials",
        scope: "https://vipps.no/ecomm/v2"
      }

      response = self.class.post(
        "/accesstoken/get",
        headers: {
          "Content-Type" => "application/x-www-form-urlencoded",
          "Ocp-Apim-Subscription-Key" => @subscription_key
        },
        body: URI.encode_www_form(auth_request)
      )

      if response.code == 200
        token_data = JSON.parse(response.body)
        @access_token = token_data["access_token"]
        @token_expires_at = Time.current + token_data["expires_in"].seconds
      else
        raise "VIPPS authentication failed: #{response.body}"
      end
    end

    def vipps_headers
      {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{@access_token}",
        "Ocp-Apim-Subscription-Key" => @subscription_key,
        "Merchant-Serial-Number" => @merchant_serial_number,
        "Vipps-System-Name" => "Public Healthcare Platform",
        "Vipps-System-Version" => "1.0.0"
      }
    end

    def handle_vipps_response(response)
      case response.code
      when 200, 201
        {
          success: true,
          data: JSON.parse(response.body),
          status_code: response.code
        }
      when 400
        {
          success: false,
          error: "Bad request",
          details: JSON.parse(response.body),
          status_code: response.code
        }
      when 401
        {
          success: false,
          error: "Unauthorized - check credentials",
          status_code: response.code
        }
      when 402
        {
          success: false,
          error: "Payment required",
          status_code: response.code
        }
      when 500
        {
          success: false,
          error: "VIPPS internal server error",
          status_code: response.code
        }
      else
        {
          success: false,
          error: "Unexpected response",
          status_code: response.code,
          body: response.body
        }
      end
    end

    def normalize_phone_number(phone)
      # Ensure Norwegian phone number format
      cleaned = phone.gsub(/\D/, "")
      
      # Add country code if not present
      if cleaned.length == 8
        "+47#{cleaned}"
      elsif cleaned.start_with?("47") && cleaned.length == 10
        "+#{cleaned}"
      elsif cleaned.start_with?("+47")
        cleaned
      else
        "+47#{cleaned[-8..-1]}" # Take last 8 digits and add Norwegian prefix
      end
    end

    def verify_bankid_status(user_details)
      # Check if user completed BankID verification
      # This would integrate with actual BankID verification endpoints
      {
        verified: user_details["dateOfBirth"].present?,
        national_id_verified: user_details["ssn"].present?,
        address_verified: user_details["addresses"].present?,
        verification_level: determine_verification_level(user_details)
      }
    end

    def determine_verification_level(user_details)
      score = 0
      score += 1 if user_details["dateOfBirth"].present?
      score += 1 if user_details["ssn"].present?
      score += 1 if user_details["addresses"].present?
      score += 1 if user_details["email"].present?

      case score
      when 4
        "high"
      when 3
        "medium"
      when 2
        "basic"
      else
        "low"
      end
    end
  end
end