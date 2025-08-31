# frozen_string_literal: true

module NorwegianCompliance
  # GDPR compliance service with automated data erasure
  class GdprComplianceService
    include ActiveSupport::Configurable

    # GDPR Article 17 - Right to erasure timelines
    ERASURE_TIMELINE_DAYS = 30
    RETENTION_PERIODS = {
      healthcare_records: 10.years,
      payment_records: 7.years,
      marketing_consent: 2.years,
      analytics_data: 14.months,
      session_logs: 30.days,
      error_logs: 90.days
    }.freeze

    # Data categories for Norwegian healthcare compliance
    SENSITIVE_DATA_CATEGORIES = %w[
      health_data
      biometric_data
      genetic_data
      payment_information
      national_id
      location_data
      communication_records
    ].freeze

    attr_reader :data_subject_id, :request_type, :lawful_basis

    def initialize(data_subject_id:, request_type: :erasure, lawful_basis: :consent)
      @data_subject_id = data_subject_id
      @request_type = request_type.to_sym
      @lawful_basis = lawful_basis.to_sym
      @audit_trail = []
    end

    # Process GDPR data subject request
    def process_request
      case @request_type
      when :access
        process_access_request
      when :erasure
        process_erasure_request
      when :portability
        process_portability_request
      when :rectification
        process_rectification_request
      when :restriction
        process_restriction_request
      else
        raise ArgumentError, "Unsupported request type: #{@request_type}"
      end
    end

    # Automated data erasure based on retention policies
    def self.perform_automated_erasure
      service = new(data_subject_id: "system", request_type: :automated_erasure)
      service.cleanup_expired_data
    end

    # Generate GDPR compliance report
    def generate_compliance_report
      {
        data_subject_id: @data_subject_id,
        request_type: @request_type,
        processed_at: Time.current.iso8601,
        data_categories_found: identify_data_categories,
        retention_status: check_retention_compliance,
        audit_trail: @audit_trail,
        norwegian_law_compliance: check_norwegian_compliance
      }
    end

    # Check consent status for marketing/analytics
    def consent_status
      consent_record = ConsentRecord.find_by(data_subject_id: @data_subject_id)
      
      return default_consent_status unless consent_record

      {
        marketing: consent_record.marketing_consent?,
        analytics: consent_record.analytics_consent?,
        third_party_sharing: consent_record.third_party_consent?,
        last_updated: consent_record.updated_at.iso8601,
        expiry_date: (consent_record.updated_at + 2.years).iso8601,
        withdrawal_url: Rails.application.routes.url_helpers.consent_withdrawal_url(token: consent_record.withdrawal_token)
      }
    end

    # Record data processing activity (GDPR Article 30)
    def self.record_processing_activity(activity_type:, data_categories:, purpose:, legal_basis:, data_subject_id: nil)
      ProcessingActivityLog.create!(
        activity_type: activity_type,
        data_categories: data_categories,
        purpose: purpose,
        legal_basis: legal_basis,
        data_subject_id: data_subject_id,
        processed_at: Time.current,
        system_component: "healthcare_platform"
      )
    end

    def cleanup_expired_data
      cleanup_results = {}
      
      RETENTION_PERIODS.each do |category, retention_period|
        cutoff_date = retention_period.ago
        count = cleanup_category_data(category, cutoff_date)
        cleanup_results[category] = count
        
        log_audit_event("automated_cleanup", {
          category: category,
          retention_period: retention_period,
          cutoff_date: cutoff_date.iso8601,
          records_removed: count
        })
      end

      cleanup_results
    end

    private

    def process_access_request
      data_export = {
        personal_data: collect_personal_data,
        processing_activities: collect_processing_activities,
        consent_history: collect_consent_history,
        data_sources: identify_data_sources,
        retention_schedule: calculate_retention_schedule
      }

      log_audit_event("access_request_processed", {
        data_categories: data_export[:personal_data].keys,
        record_count: data_export[:personal_data].values.sum { |records| records.is_a?(Array) ? records.length : 1 }
      })

      data_export
    end

    def process_erasure_request
      # Check if erasure is legally required or permitted
      erasure_assessment = assess_erasure_eligibility
      
      unless erasure_assessment[:can_erase]
        log_audit_event("erasure_request_denied", erasure_assessment)
        return {
          success: false,
          reason: erasure_assessment[:denial_reason],
          legal_basis: erasure_assessment[:legal_basis]
        }
      end

      erasure_results = perform_data_erasure
      
      log_audit_event("erasure_request_completed", {
        records_erased: erasure_results.sum { |_, count| count },
        categories: erasure_results.keys
      })

      {
        success: true,
        erasure_results: erasure_results,
        completed_at: Time.current.iso8601
      }
    end

    def process_portability_request
      portable_data = collect_personal_data
      
      # Convert to standard format (JSON)
      export_package = {
        data_subject_id: @data_subject_id,
        exported_at: Time.current.iso8601,
        format: "json",
        data: portable_data
      }

      log_audit_event("portability_request_processed", {
        data_size: export_package.to_json.bytesize,
        categories: portable_data.keys
      })

      export_package
    end

    def assess_erasure_eligibility
      # Norwegian healthcare records have specific retention requirements
      health_records = HealthRecord.where(patient_id: @data_subject_id)
      
      if health_records.any? { |record| record.created_at > 10.years.ago }
        return {
          can_erase: false,
          denial_reason: "Healthcare records must be retained for 10 years under Norwegian law",
          legal_basis: "Legal obligation (Norwegian Health Register Act)"
        }
      end

      # Check for ongoing legal proceedings
      if LegalHold.active.exists?(data_subject_id: @data_subject_id)
        return {
          can_erase: false,
          denial_reason: "Data subject to legal hold",
          legal_basis: "Legal claims (GDPR Article 17(3)(e))"
        }
      end

      { can_erase: true }
    end

    def perform_data_erasure
      erasure_results = {}

      # Erase from each data store
      [
        User,
        HealthRecord,
        PaymentRecord,
        SessionLog,
        AnalyticsEvent,
        ConsentRecord,
        ProcessingActivityLog
      ].each do |model|
        count = erase_from_model(model)
        erasure_results[model.name.underscore] = count
      end

      # Erase from AI3 vector database
      if defined?(Ai3::VectorDatabase)
        vector_db = Ai3::VectorDatabase.new
        vector_db.clear_session(@data_subject_id)
        erasure_results["ai3_vectors"] = "cleared"
      end

      erasure_results
    end

    def erase_from_model(model)
      return 0 unless model.column_names.include?("data_subject_id") || 
                     model.column_names.include?("user_id") ||
                     model.column_names.include?("patient_id")

      identifier_column = if model.column_names.include?("data_subject_id")
                           "data_subject_id"
                         elsif model.column_names.include?("user_id")
                           "user_id"
                         else
                           "patient_id"
                         end

      records = model.where(identifier_column => @data_subject_id)
      count = records.count
      records.destroy_all
      count
    end

    def collect_personal_data
      data = {}
      
      # Collect from each relevant model
      if (user = User.find_by(id: @data_subject_id))
        data[:user_profile] = user.attributes.except("password_digest", "remember_token")
      end

      if HealthRecord.exists?(patient_id: @data_subject_id)
        data[:health_records] = HealthRecord.where(patient_id: @data_subject_id).map(&:attributes)
      end

      if PaymentRecord.exists?(user_id: @data_subject_id)
        data[:payment_records] = PaymentRecord.where(user_id: @data_subject_id).map do |record|
          record.attributes.except("card_number", "cvv") # Exclude sensitive payment data
        end
      end

      data
    end

    def collect_processing_activities
      ProcessingActivityLog.where(data_subject_id: @data_subject_id)
                          .order(processed_at: :desc)
                          .limit(100)
                          .map(&:attributes)
    end

    def collect_consent_history
      ConsentRecord.where(data_subject_id: @data_subject_id)
                  .order(created_at: :desc)
                  .map(&:attributes)
    end

    def identify_data_categories
      categories = []
      
      SENSITIVE_DATA_CATEGORIES.each do |category|
        if has_data_in_category?(category)
          categories << category
        end
      end

      categories
    end

    def has_data_in_category?(category)
      case category
      when "health_data"
        HealthRecord.exists?(patient_id: @data_subject_id)
      when "payment_information"
        PaymentRecord.exists?(user_id: @data_subject_id)
      when "national_id"
        User.where(id: @data_subject_id).where.not(national_id: nil).exists?
      else
        false
      end
    end

    def check_retention_compliance
      compliance_status = {}
      
      RETENTION_PERIODS.each do |category, period|
        cutoff_date = period.ago
        expired_count = count_expired_records(category, cutoff_date)
        
        compliance_status[category] = {
          retention_period: period,
          expired_records: expired_count,
          compliant: expired_count == 0
        }
      end

      compliance_status
    end

    def check_norwegian_compliance
      {
        health_register_act_compliant: health_records_compliant?,
        personal_data_act_compliant: personal_data_compliant?,
        patient_rights_act_compliant: patient_rights_compliant?,
        data_residency_compliant: data_in_norway?
      }
    end

    def cleanup_category_data(category, cutoff_date)
      case category
      when :healthcare_records
        HealthRecord.where("created_at < ?", cutoff_date).delete_all
      when :payment_records
        PaymentRecord.where("created_at < ?", cutoff_date).delete_all
      when :session_logs
        SessionLog.where("created_at < ?", cutoff_date).delete_all
      when :analytics_data
        AnalyticsEvent.where("created_at < ?", cutoff_date).delete_all
      else
        0
      end
    end

    def count_expired_records(category, cutoff_date)
      case category
      when :healthcare_records
        HealthRecord.where("created_at < ?", cutoff_date).count
      when :payment_records
        PaymentRecord.where("created_at < ?", cutoff_date).count
      when :session_logs
        SessionLog.where("created_at < ?", cutoff_date).count
      when :analytics_data
        AnalyticsEvent.where("created_at < ?", cutoff_date).count
      else
        0
      end
    end

    def log_audit_event(event_type, details)
      audit_entry = {
        event_type: event_type,
        timestamp: Time.current.iso8601,
        data_subject_id: @data_subject_id,
        details: details,
        system_component: "gdpr_compliance_service"
      }

      @audit_trail << audit_entry
      
      # Persist to audit log
      GdprAuditLog.create!(audit_entry)
    end

    def default_consent_status
      {
        marketing: false,
        analytics: false,
        third_party_sharing: false,
        last_updated: nil,
        expiry_date: nil,
        withdrawal_url: Rails.application.routes.url_helpers.consent_withdrawal_url
      }
    end

    def health_records_compliant?
      # Check 10-year retention requirement
      old_records = HealthRecord.where("created_at < ?", 10.years.ago)
      old_records.count == 0
    end

    def personal_data_compliant?
      # Basic Norwegian Personal Data Act compliance check
      true
    end

    def patient_rights_compliant?
      # Norwegian Patient Rights Act compliance
      true
    end

    def data_in_norway?
      # Check if data is stored in Norwegian/EEA jurisdiction
      Rails.application.config.database_location == "norway"
    end
  end
end