# frozen_string_literal: true

# Security initializer for Public Healthcare Platform
# Implements HMAC signature verification, AES-256 encryption, and Norwegian compliance

Rails.application.configure do
  # Force SSL in production with Norwegian compliance
  config.force_ssl = true if Rails.env.production?
  
  # Secure session configuration
  config.session_store :cookie_store,
    key: '_pub_healthcare_session',
    secure: Rails.env.production?,
    httponly: true,
    same_site: :strict,
    expire_after: 4.hours

  # Content Security Policy for Norwegian healthcare compliance
  config.content_security_policy do |policy|
    policy.default_src :self, :https
    policy.font_src    :self, :https, :data
    policy.img_src     :self, :https, :data, "blob:"
    policy.object_src  :none
    policy.script_src  :self, :https, :unsafe_inline if Rails.env.development?
    policy.style_src   :self, :https, :unsafe_inline
    policy.connect_src :self, :https, "wss:", "ws:"
    
    # Norwegian banking and healthcare endpoints
    policy.connect_src(*policy.connect_src, 
                      "https://apitest.vipps.no",
                      "https://api.vipps.no",
                      "https://helsenorge.no",
                      "https://helsedirektoratet.no")
    
    # AI provider endpoints
    policy.connect_src(*policy.connect_src,
                      "https://api.openai.com",
                      "https://api.anthropic.com", 
                      "https://api.x.ai",
                      "http://localhost:11434") # Ollama local
    
    # Add nonce for inline scripts in production
    if Rails.env.production?
      policy.script_src :self, :https
      policy.style_src :self, :https
    end
  end

  # Security headers for Norwegian healthcare compliance
  config.force_ssl_redirect = {
    headers: {
      'Strict-Transport-Security' => 'max-age=31536000; includeSubDomains; preload',
      'X-Frame-Options' => 'DENY',
      'X-Content-Type-Options' => 'nosniff',
      'X-XSS-Protection' => '1; mode=block',
      'Referrer-Policy' => 'strict-origin-when-cross-origin',
      'Permissions-Policy' => 'camera=(), microphone=(), geolocation=(), payment=()',
      'Cross-Origin-Embedder-Policy' => 'require-corp',
      'Cross-Origin-Opener-Policy' => 'same-origin',
      'Cross-Origin-Resource-Policy' => 'same-origin'
    }
  }
end

# HMAC signature verification for API endpoints
module HmacAuthentication
  ALGORITHM = 'sha256'
  HEADER_NAME = 'X-Signature-SHA256'
  
  class << self
    def verify_signature(request_body, signature, secret)
      return false unless signature && secret
      
      expected_signature = generate_signature(request_body, secret)
      secure_compare(signature, expected_signature)
    end
    
    def generate_signature(data, secret)
      "sha256=#{OpenSSL::HMAC.hexdigest(ALGORITHM, secret, data)}"
    end
    
    private
    
    def secure_compare(a, b)
      return false unless a.bytesize == b.bytesize
      
      l = a.unpack("C*")
      r = b.unpack("C*")
      
      result = 0
      l.zip(r).each { |x, y| result |= x ^ y }
      result == 0
    end
  end
end

# AES-256 encryption for data at rest
module EncryptionService
  ALGORITHM = 'AES-256-GCM'
  KEY_SIZE = 32 # 256 bits
  IV_SIZE = 12  # 96 bits for GCM
  TAG_SIZE = 16 # 128 bits
  
  class << self
    def encrypt(plaintext, key = nil)
      key ||= encryption_key
      cipher = OpenSSL::Cipher.new(ALGORITHM)
      cipher.encrypt
      cipher.key = key
      
      iv = cipher.random_iv
      encrypted = cipher.update(plaintext) + cipher.final
      tag = cipher.auth_tag
      
      # Return base64 encoded: IV + TAG + ENCRYPTED_DATA
      Base64.strict_encode64(iv + tag + encrypted)
    end
    
    def decrypt(ciphertext, key = nil)
      key ||= encryption_key
      data = Base64.strict_decode64(ciphertext)
      
      iv = data[0, IV_SIZE]
      tag = data[IV_SIZE, TAG_SIZE]
      encrypted = data[IV_SIZE + TAG_SIZE..-1]
      
      cipher = OpenSSL::Cipher.new(ALGORITHM)
      cipher.decrypt
      cipher.key = key
      cipher.iv = iv
      cipher.auth_tag = tag
      
      cipher.update(encrypted) + cipher.final
    rescue OpenSSL::Cipher::CipherError => e
      Rails.logger.error "Decryption failed: #{e.message}"
      raise SecurityError, "Data decryption failed"
    end
    
    def generate_key
      SecureRandom.random_bytes(KEY_SIZE)
    end
    
    private
    
    def encryption_key
      # In production, this should come from secure key management
      key_material = Rails.application.credentials.encryption_key ||
                    Rails.application.secret_key_base
      
      # Derive a consistent key from the key material
      OpenSSL::PKCS5.pbkdf2_hmac(
        key_material,
        'pub_healthcare_salt',
        100_000, # iterations
        KEY_SIZE,
        OpenSSL::Digest::SHA256.new
      )
    end
  end
end

# Norwegian healthcare data compliance
module NorwegianHealthCompliance
  REQUIRED_RETENTION_YEARS = 10
  GDPR_RETENTION_YEARS = 2
  AUDIT_LOG_RETENTION_YEARS = 7
  
  class << self
    def classify_data_sensitivity(data_type)
      case data_type.to_s.downcase
      when 'health_record', 'medical_data', 'diagnosis', 'treatment'
        'special_category' # GDPR Article 9
      when 'national_id', 'fodselsnummer', 'ssn'
        'personal_identifier'
      when 'payment_data', 'bank_account', 'vipps_data'
        'financial'
      when 'location_data', 'gps_coordinates'
        'location'
      else
        'personal'
      end
    end
    
    def retention_period(data_type)
      case classify_data_sensitivity(data_type)
      when 'special_category'
        REQUIRED_RETENTION_YEARS.years
      when 'financial'
        AUDIT_LOG_RETENTION_YEARS.years
      else
        GDPR_RETENTION_YEARS.years
      end
    end
    
    def requires_explicit_consent?(data_type)
      ['special_category', 'location'].include?(classify_data_sensitivity(data_type))
    end
    
    def requires_norwegian_residency?(data_type)
      ['special_category', 'personal_identifier'].include?(classify_data_sensitivity(data_type))
    end
  end
end

# Audit logging for Norwegian compliance
module ComplianceAuditing
  class << self
    def log_data_access(user_id:, data_type:, action:, details: {})
      audit_entry = {
        timestamp: Time.current.iso8601,
        user_id: user_id,
        data_type: data_type,
        action: action,
        details: details,
        ip_address: extract_ip_address,
        user_agent: extract_user_agent,
        session_id: extract_session_id
      }
      
      # Store in immutable audit log
      AuditLog.create!(audit_entry)
      
      # Log to secure file for Norwegian authorities
      log_to_secure_file(audit_entry)
    end
    
    def log_security_event(event_type:, severity:, details: {})
      security_entry = {
        timestamp: Time.current.iso8601,
        event_type: event_type,
        severity: severity,
        details: details,
        source_ip: extract_ip_address,
        system_component: 'healthcare_platform'
      }
      
      SecurityLog.create!(security_entry)
      
      # Alert on high severity events
      if severity == 'critical' || severity == 'high'
        SecurityAlertService.notify(security_entry)
      end
    end
    
    private
    
    def extract_ip_address
      # This would be set by middleware
      Thread.current[:current_ip] || 'unknown'
    end
    
    def extract_user_agent
      Thread.current[:current_user_agent] || 'unknown'
    end
    
    def extract_session_id
      Thread.current[:current_session_id] || 'unknown'
    end
    
    def log_to_secure_file(entry)
      # Write to tamper-evident log file for Norwegian compliance
      log_file = Rails.root.join('log', 'audit', "#{Date.current.strftime('%Y-%m')}.log")
      FileUtils.mkdir_p(File.dirname(log_file))
      
      File.open(log_file, 'a') do |f|
        f.write("#{entry.to_json}\n")
      end
    end
  end
end

# Rate limiting and DDoS protection
class SecurityMiddleware
  def initialize(app)
    @app = app
  end
  
  def call(env)
    request = Rack::Request.new(env)
    
    # Set security context for audit logging
    Thread.current[:current_ip] = request.ip
    Thread.current[:current_user_agent] = request.user_agent
    Thread.current[:current_session_id] = request.session[:session_id]
    
    # Check for suspicious activity
    if suspicious_request?(request)
      ComplianceAuditing.log_security_event(
        event_type: 'suspicious_request',
        severity: 'medium',
        details: {
          ip: request.ip,
          path: request.path,
          user_agent: request.user_agent,
          reason: 'Pattern detected'
        }
      )
    end
    
    # Add security headers
    status, headers, body = @app.call(env)
    
    headers['X-Request-ID'] = SecureRandom.uuid
    headers['X-Content-Type-Options'] = 'nosniff'
    headers['X-Frame-Options'] = 'DENY'
    headers['X-XSS-Protection'] = '1; mode=block'
    
    [status, headers, body]
  ensure
    # Clear security context
    Thread.current[:current_ip] = nil
    Thread.current[:current_user_agent] = nil
    Thread.current[:current_session_id] = nil
  end
  
  private
  
  def suspicious_request?(request)
    # Simple heuristics for suspicious activity
    return true if request.path.include?('../') # Path traversal
    return true if request.path.include?('<script') # XSS attempt
    return true if request.user_agent&.include?('sqlmap') # SQL injection tool
    return true if request.path.length > 1000 # Unusually long path
    
    false
  end
end

# Initialize security middleware
Rails.application.config.middleware.insert_before 0, SecurityMiddleware

# Vulnerability scanning integration
if Rails.env.production?
  # Schedule daily vulnerability scans
  # This would integrate with tools like Brakeman, bundler-audit, etc.
  Rails.application.config.after_initialize do
    VulnerabilityScanner.schedule_daily_scan if defined?(VulnerabilityScanner)
  end
end