# frozen_string_literal: true

module NorwegianCompliance
  # MVA (Norwegian VAT) calculation service with 25% standard rate
  class MvaCalculationService
    STANDARD_RATE = 0.25
    REDUCED_RATE = 0.15
    LOW_RATE = 0.12
    EXEMPT_RATE = 0.0

    # Healthcare services are typically exempt from MVA
    HEALTHCARE_SERVICES = %w[
      medical_consultation
      hospital_treatment
      dental_care
      physiotherapy
      mental_health_services
      emergency_care
      prescription_medication
      medical_equipment
    ].freeze

    # Reduced rate categories
    REDUCED_RATE_CATEGORIES = %w[
      food_products
      books
      newspapers
      passenger_transport
      accommodation
    ].freeze

    # Low rate categories  
    LOW_RATE_CATEGORIES = %w[
      cinema_tickets
      cultural_events
      sporting_events
    ].freeze

    attr_reader :amount, :category, :rate, :vat_amount, :total_amount

    def initialize(amount:, category:, customer_location: "NO")
      @amount = BigDecimal(amount.to_s)
      @category = category.to_s
      @customer_location = customer_location
      @rate = determine_vat_rate
      calculate_vat
    end

    def calculate_vat
      @vat_amount = @amount * @rate
      @total_amount = @amount + @vat_amount
    end

    def vat_inclusive?
      @rate > 0
    end

    def exempt?
      @rate == 0
    end

    def healthcare_exempt?
      HEALTHCARE_SERVICES.include?(@category)
    end

    def to_hash
      {
        base_amount: @amount.to_f,
        vat_rate: (@rate * 100).to_f,
        vat_amount: @vat_amount.to_f,
        total_amount: @total_amount.to_f,
        category: @category,
        exempt: exempt?,
        healthcare_exempt: healthcare_exempt?,
        currency: "NOK",
        calculated_at: Time.current.iso8601
      }
    end

    def self.exempt_categories
      HEALTHCARE_SERVICES
    end

    def self.calculate_for_healthcare_transaction(amount, service_type)
      new(amount: amount, category: service_type)
    end

    private

    def determine_vat_rate
      # Healthcare services are exempt
      return EXEMPT_RATE if HEALTHCARE_SERVICES.include?(@category)
      
      # Non-Norwegian customers may have different rules
      return handle_international_customer if @customer_location != "NO"
      
      # Apply Norwegian MVA rates
      case @category
      when *REDUCED_RATE_CATEGORIES
        REDUCED_RATE
      when *LOW_RATE_CATEGORIES
        LOW_RATE
      else
        STANDARD_RATE
      end
    end

    def handle_international_customer
      # Simplified international VAT handling
      # In practice, this would involve complex EU/EEA rules
      case @customer_location
      when "SE", "DK", "FI" # Nordic countries
        STANDARD_RATE
      when /^(US|CA|AU|NZ)/ # Non-EU countries
        EXEMPT_RATE
      else # EU countries
        # Reverse charge mechanism for B2B
        EXEMPT_RATE
      end
    end
  end
end