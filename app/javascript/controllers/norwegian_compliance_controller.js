// Norwegian compliance controller for GDPR, payment, and localization
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["consentForm", "paymentForm", "dataExport", "locale", "currency"]
  static values = {
    locale: { type: String, default: "nb_NO" },
    currency: { type: String, default: "NOK" },
    gdprEndpoint: { type: String, default: "/api/compliance/gdpr" },
    paymentEndpoint: { type: String, default: "/api/payment/vipps" }
  }

  connect() {
    this.initializeLocalization()
    this.setupGDPRCompliance()
    this.initializePaymentHandling()
  }

  // Handle consent form submission
  async submitConsent(event) {
    event.preventDefault()
    
    const formData = new FormData(this.consentFormTarget)
    const consentData = {
      marketing: formData.get('consent_marketing') === 'on',
      analytics: formData.get('consent_analytics') === 'on', 
      third_party: formData.get('consent_third_party') === 'on',
      locale: this.localeValue,
      timestamp: new Date().toISOString()
    }

    try {
      const response = await fetch(`${this.gdprEndpointValue}/consent`, {
        method: 'POST',
        headers: this.getHeaders(),
        body: JSON.stringify(consentData)
      })

      if (response.ok) {
        this.showSuccess("Samtykke registrert")
        this.updateConsentStatus(consentData)
      } else {
        throw new Error(`HTTP ${response.status}`)
      }
    } catch (error) {
      this.showError("Feil ved registrering av samtykke")
      console.error("Consent submission failed:", error)
    }
  }

  // Request data export (GDPR Article 15)
  async requestDataExport(event) {
    event.preventDefault()
    
    const exportType = event.target.dataset.exportType || 'full'
    
    try {
      this.setExportStatus("processing", "Forbereder dataeksport...")
      
      const response = await fetch(`${this.gdprEndpointValue}/export`, {
        method: 'POST',
        headers: this.getHeaders(),
        body: JSON.stringify({
          export_type: exportType,
          format: 'json',
          locale: this.localeValue
        })
      })

      if (response.ok) {
        const result = await response.json()
        this.handleDataExport(result)
      } else {
        throw new Error(`HTTP ${response.status}`)
      }
    } catch (error) {
      this.setExportStatus("error", "Feil ved dataeksport")
      console.error("Data export failed:", error)
    }
  }

  // Request data deletion (GDPR Article 17)
  async requestDataDeletion(event) {
    event.preventDefault()
    
    const confirmed = confirm(
      "Er du sikker på at du vil slette alle dine data? " +
      "Denne handlingen kan ikke angres. " +
      "Helsedata oppbevares i 10 år iht. norsk lov."
    )
    
    if (!confirmed) return
    
    try {
      const response = await fetch(`${this.gdprEndpointValue}/erasure`, {
        method: 'DELETE',
        headers: this.getHeaders()
      })

      if (response.ok) {
        const result = await response.json()
        this.handleDeletionResult(result)
      } else {
        throw new Error(`HTTP ${response.status}`)
      }
    } catch (error) {
      this.showError("Feil ved datasletting")
      console.error("Data deletion failed:", error)
    }
  }

  // Initialize VIPPS payment
  async initiateVippsPayment(event) {
    event.preventDefault()
    
    const formData = new FormData(this.paymentFormTarget)
    const paymentData = {
      amount: parseFloat(formData.get('amount')),
      customer_phone: formData.get('phone'),
      service_type: formData.get('service_type'),
      callback_url: window.location.origin + '/payment/callback',
      fallback_url: window.location.origin + '/payment/fallback'
    }

    // Validate Norwegian phone number
    if (!this.validateNorwegianPhone(paymentData.customer_phone)) {
      this.showError("Ugyldig norsk telefonnummer")
      return
    }

    try {
      this.setPaymentStatus("processing", "Starter VIPPS-betaling...")
      
      const response = await fetch(`${this.paymentEndpointValue}/initiate`, {
        method: 'POST',
        headers: this.getHeaders(),
        body: JSON.stringify(paymentData)
      })

      if (response.ok) {
        const result = await response.json()
        this.handleVippsInitiation(result)
      } else {
        throw new Error(`HTTP ${response.status}`)
      }
    } catch (error) {
      this.setPaymentStatus("error", "Feil ved oppstart av betaling")
      console.error("VIPPS payment initiation failed:", error)
    }
  }

  // Change locale
  changeLocale(event) {
    const newLocale = event.target.value
    this.localeValue = newLocale
    
    // Update currency based on locale
    if (newLocale.startsWith('nb') || newLocale.startsWith('nn')) {
      this.currencyValue = 'NOK'
    } else if (newLocale.startsWith('en_US')) {
      this.currencyValue = 'USD'
    }
    
    this.updateLocalization()
    this.saveLocalePreference(newLocale)
  }

  // Calculate Norwegian MVA (VAT)
  calculateMVA(amount, serviceType = 'standard') {
    const mvaRates = {
      healthcare: 0.0,   // Healthcare exempt
      standard: 0.25,    // 25% standard rate
      reduced: 0.15,     // Reduced rate
      low: 0.12          // Low rate
    }
    
    const rate = mvaRates[serviceType] || mvaRates.standard
    const mvaAmount = amount * rate
    const totalAmount = amount + mvaAmount
    
    return {
      baseAmount: amount,
      mvaRate: rate * 100,
      mvaAmount: mvaAmount,
      totalAmount: totalAmount,
      currency: this.currencyValue
    }
  }

  // Format currency according to Norwegian standards
  formatCurrency(amount) {
    return new Intl.NumberFormat(this.localeValue, {
      style: 'currency',
      currency: this.currencyValue,
      minimumFractionDigits: 2
    }).format(amount)
  }

  // Format Norwegian national ID
  formatNationalId(nationalId) {
    if (!nationalId || nationalId.length !== 11) return nationalId
    
    return `${nationalId.slice(0, 6)} ${nationalId.slice(6)}`
  }

  // Validate Norwegian phone number
  validateNorwegianPhone(phone) {
    if (!phone) return false
    
    // Remove all non-digits
    const cleaned = phone.replace(/\D/g, '')
    
    // Check various Norwegian phone formats
    return (
      /^[49]\d{7}$/.test(cleaned) ||           // 8 digits starting with 4 or 9
      /^47[49]\d{7}$/.test(cleaned) ||         // With country code 47
      /^\+47[49]\d{7}$/.test(phone)            // With +47 prefix
    )
  }

  // Show Norwegian health system information
  showHealthSystemInfo() {
    const healthInfo = {
      emergency: {
        medical: "113",
        fire: "110", 
        police: "112",
        poison: "22 59 13 00"
      },
      patientRights: {
        freeTreatment: true,
        annualCeiling: 3275, // NOK 2024
        prescriptionCeiling: 2300 // NOK 2024
      }
    }
    
    const infoModal = this.createHealthInfoModal(healthInfo)
    document.body.appendChild(infoModal)
    infoModal.showModal()
  }

  private

  initializeLocalization() {
    // Set page language
    document.documentElement.lang = this.localeValue.split('_')[0]
    
    // Update currency displays
    this.updateCurrencyDisplays()
    
    // Update date/time formats
    this.updateDateTimeFormats()
  }

  setupGDPRCompliance() {
    // Add GDPR compliance notices
    this.addGDPRNotices()
    
    // Setup automatic data retention cleanup
    this.scheduleDataRetentionCheck()
  }

  initializePaymentHandling() {
    // Setup MVA calculation for payment forms
    this.setupMVACalculation()
    
    // Initialize VIPPS integration
    this.setupVippsIntegration()
  }

  handleDataExport(result) {
    if (result.success) {
      this.setExportStatus("success", "Dataeksport klar for nedlasting")
      this.createDownloadLink(result.download_url, "mine_data.json")
    } else {
      this.setExportStatus("error", "Dataeksport feilet")
    }
  }

  handleDeletionResult(result) {
    if (result.success) {
      this.showSuccess("Datasletting fullført")
      // Redirect to confirmation page
      window.location.href = "/data-deleted"
    } else {
      this.showError(`Datasletting ikke mulig: ${result.reason}`)
    }
  }

  handleVippsInitiation(result) {
    if (result.success && result.data.url) {
      this.setPaymentStatus("redirect", "Videresender til VIPPS...")
      window.location.href = result.data.url
    } else {
      this.setPaymentStatus("error", "Kunne ikke starte VIPPS-betaling")
    }
  }

  updateConsentStatus(consentData) {
    // Update UI to reflect current consent status
    const statusElement = document.querySelector('[data-consent-status]')
    if (statusElement) {
      statusElement.innerHTML = this.renderConsentStatus(consentData)
    }
  }

  renderConsentStatus(consent) {
    return `
      <div class="consent-status">
        <h3>Ditt samtykke</h3>
        <ul>
          <li>Markedsføring: ${consent.marketing ? '✓ Ja' : '✗ Nei'}</li>
          <li>Analyse: ${consent.analytics ? '✓ Ja' : '✗ Nei'}</li>
          <li>Tredjeparter: ${consent.third_party ? '✓ Ja' : '✗ Nei'}</li>
        </ul>
        <p><small>Sist oppdatert: ${new Date(consent.timestamp).toLocaleDateString('nb-NO')}</small></p>
      </div>
    `
  }

  createDownloadLink(url, filename) {
    const link = document.createElement('a')
    link.href = url
    link.download = filename
    link.textContent = `Last ned ${filename}`
    link.className = 'download-link'
    
    if (this.hasDataExportTarget) {
      this.dataExportTarget.appendChild(link)
    }
    
    // Auto-click to start download
    link.click()
  }

  createHealthInfoModal(healthInfo) {
    const modal = document.createElement('dialog')
    modal.className = 'health-info-modal'
    modal.innerHTML = `
      <div class="modal-content">
        <h2>Norsk helsevesen</h2>
        <div class="emergency-numbers">
          <h3>Nødnumre</h3>
          <ul>
            <li><strong>113</strong> - Medisinsk nødhjelp</li>
            <li><strong>110</strong> - Brann</li>
            <li><strong>112</strong> - Politi</li>
            <li><strong>22 59 13 00</strong> - Giftinformasjon</li>
          </ul>
        </div>
        <div class="patient-rights">
          <h3>Pasientrettigheter</h3>
          <ul>
            <li>Gratis behandling i offentlige helsetjenester</li>
            <li>Egenandelstak: ${this.formatCurrency(healthInfo.patientRights.annualCeiling)}</li>
            <li>Resepttak: ${this.formatCurrency(healthInfo.patientRights.prescriptionCeiling)}</li>
          </ul>
        </div>
        <button type="button" onclick="this.closest('dialog').close()">Lukk</button>
      </div>
    `
    
    return modal
  }

  setExportStatus(type, message) {
    const statusEl = document.querySelector('[data-export-status]')
    if (statusEl) {
      statusEl.className = `export-status export-status--${type}`
      statusEl.textContent = message
    }
  }

  setPaymentStatus(type, message) {
    const statusEl = document.querySelector('[data-payment-status]')
    if (statusEl) {
      statusEl.className = `payment-status payment-status--${type}`
      statusEl.textContent = message
    }
  }

  showSuccess(message) {
    window.showHealthcareNotification('success', message)
  }

  showError(message) {
    window.showHealthcareNotification('error', message)
  }

  updateLocalization() {
    // Update all localizable elements on the page
    document.querySelectorAll('[data-localize]').forEach(el => {
      const key = el.dataset.localize
      el.textContent = this.getLocalizedText(key)
    })
  }

  updateCurrencyDisplays() {
    document.querySelectorAll('[data-currency]').forEach(el => {
      const amount = parseFloat(el.dataset.amount || el.textContent)
      if (!isNaN(amount)) {
        el.textContent = this.formatCurrency(amount)
      }
    })
  }

  updateDateTimeFormats() {
    document.querySelectorAll('[data-datetime]').forEach(el => {
      const datetime = el.dataset.datetime
      if (datetime) {
        el.textContent = new Date(datetime).toLocaleString(this.localeValue, {
          timeZone: 'Europe/Oslo'
        })
      }
    })
  }

  getLocalizedText(key) {
    // Simple localization - in production, this would use proper i18n
    const translations = {
      nb_NO: {
        'submit': 'Send inn',
        'cancel': 'Avbryt',
        'loading': 'Laster...',
        'error': 'Feil',
        'success': 'Vellykket'
      },
      en_US: {
        'submit': 'Submit',
        'cancel': 'Cancel', 
        'loading': 'Loading...',
        'error': 'Error',
        'success': 'Success'
      }
    }
    
    return translations[this.localeValue]?.[key] || key
  }

  saveLocalePreference(locale) {
    localStorage.setItem('preferred_locale', locale)
    
    // Send to server
    fetch('/api/user/locale', {
      method: 'PATCH',
      headers: this.getHeaders(),
      body: JSON.stringify({ locale })
    }).catch(console.error)
  }

  getHeaders() {
    const token = document.querySelector('meta[name="csrf-token"]')?.content
    const headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json'
    }
    
    if (token) {
      headers['X-CSRF-Token'] = token
    }
    
    return headers
  }
}