// AI3 Chat Controller for multi-LLM healthcare interactions
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "output", "status", "confidence", "provider", "sessionId"]
  static values = { 
    sessionId: String,
    endpoint: { type: String, default: "/api/ai3/chat" },
    autoSession: { type: Boolean, default: true }
  }

  connect() {
    this.initializeSession()
    this.setupAccessibility()
    this.bindKeyboardShortcuts()
  }

  disconnect() {
    this.clearSession()
  }

  // Send message to AI3 orchestrator
  async sendMessage(event) {
    event?.preventDefault()
    
    const message = this.inputTarget.value.trim()
    if (!message) return
    
    this.setStatus("thinking", "Sender spørsmål til AI-systemet...")
    this.disableInput()
    
    try {
      const response = await this.callAI3(message)
      this.handleAI3Response(response)
      this.clearInput()
    } catch (error) {
      this.handleError(error)
    } finally {
      this.enableInput()
      this.focusInput()
    }
  }

  // Clear current session
  async clearSession(event) {
    event?.preventDefault()
    
    if (this.sessionIdValue) {
      try {
        await fetch(`${this.endpointValue}/sessions/${this.sessionIdValue}`, {
          method: 'DELETE',
          headers: this.getHeaders()
        })
      } catch (error) {
        console.warn("Failed to clear session:", error)
      }
    }
    
    this.initializeSession()
    this.clearOutput()
    this.setStatus("ready", "Ny samtale startet")
    
    // Announce to screen readers
    window.HealthcarePlatform.announceToScreenReader("Ny samtale startet")
  }

  // Handle keyboard shortcuts
  handleKeydown(event) {
    // Ctrl+Enter or Cmd+Enter to send
    if ((event.ctrlKey || event.metaKey) && event.key === 'Enter') {
      event.preventDefault()
      this.sendMessage()
    }
    
    // Escape to clear
    if (event.key === 'Escape') {
      event.preventDefault()
      this.clearSession()
    }
  }

  private

  initializeSession() {
    if (this.autoSessionValue && !this.sessionIdValue) {
      this.sessionIdValue = this.generateSessionId()
    }
    
    if (this.hasSessionIdTarget) {
      this.sessionIdTarget.textContent = this.sessionIdValue || "Ingen sesjon"
    }
  }

  async callAI3(message) {
    const payload = {
      prompt: message,
      session_id: this.sessionIdValue,
      context: {
        platform: "healthcare",
        locale: "nb_NO",
        timestamp: new Date().toISOString()
      }
    }

    const response = await fetch(this.endpointValue, {
      method: 'POST',
      headers: this.getHeaders(),
      body: JSON.stringify(payload)
    })

    if (!response.ok) {
      throw new Error(`AI3 request failed: ${response.status} ${response.statusText}`)
    }

    return response.json()
  }

  handleAI3Response(response) {
    const { content, confidence, provider, quality, warning } = response
    
    // Update output
    this.appendToOutput("user", this.inputTarget.value)
    this.appendToOutput("assistant", content, { confidence, provider, quality })
    
    // Update status indicators
    this.updateConfidence(confidence)
    this.updateProvider(provider)
    
    // Handle quality warnings
    if (warning) {
      this.showWarning(warning)
    }
    
    // Set appropriate status
    if (quality === "high") {
      this.setStatus("success", "Høy kvalitet respons mottatt")
    } else if (quality === "medium") {
      this.setStatus("warning", "Medium kvalitet respons")
    } else {
      this.setStatus("error", "Lav kvalitet respons - vurder å omformulere")
    }
  }

  handleError(error) {
    console.error("AI3 Chat Error:", error)
    
    this.setStatus("error", "Feil ved kommunikasjon med AI-systemet")
    this.appendToOutput("system", `Feil: ${error.message}`, { isError: true })
    
    // Show user-friendly error
    window.showHealthcareNotification("error", 
      "AI-tjenesten er midlertidig utilgjengelig. Prøv igjen senere."
    )
  }

  appendToOutput(role, content, metadata = {}) {
    const messageElement = document.createElement('div')
    messageElement.className = `ai3-message ai3-message--${role}`
    messageElement.setAttribute('role', 'log')
    
    const timestamp = new Date().toLocaleTimeString('nb-NO', {
      hour: '2-digit',
      minute: '2-digit'
    })
    
    let metadataHtml = ''
    if (metadata.confidence !== undefined) {
      const confidencePercent = Math.round(metadata.confidence * 100)
      metadataHtml += `<span class="ai3-metadata__confidence" title="Tillitsnivå">${confidencePercent}%</span>`
    }
    
    if (metadata.provider) {
      metadataHtml += `<span class="ai3-metadata__provider" title="AI-leverandør">${metadata.provider}</span>`
    }
    
    messageElement.innerHTML = `
      <div class="ai3-message__header">
        <span class="ai3-message__role">${this.getRoleLabel(role)}</span>
        <span class="ai3-message__timestamp">${timestamp}</span>
        ${metadataHtml ? `<div class="ai3-metadata">${metadataHtml}</div>` : ''}
      </div>
      <div class="ai3-message__content ${metadata.isError ? 'ai3-message__content--error' : ''}">${this.formatContent(content)}</div>
    `
    
    this.outputTarget.appendChild(messageElement)
    this.scrollToBottom()
    
    // Announce assistant responses to screen readers
    if (role === 'assistant') {
      window.HealthcarePlatform.announceToScreenReader(`AI svarte: ${content}`)
    }
  }

  formatContent(content) {
    // Basic markdown-like formatting for healthcare content
    return content
      .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
      .replace(/\*(.*?)\*/g, '<em>$1</em>')
      .replace(/`(.*?)`/g, '<code>$1</code>')
      .replace(/\n/g, '<br>')
  }

  getRoleLabel(role) {
    const labels = {
      user: "Du",
      assistant: "AI Assistent", 
      system: "System"
    }
    return labels[role] || role
  }

  updateConfidence(confidence) {
    if (!this.hasConfidenceTarget) return
    
    const percentage = Math.round(confidence * 100)
    this.confidenceTarget.textContent = `${percentage}%`
    this.confidenceTarget.className = `ai3-confidence ai3-confidence--${this.getConfidenceLevel(confidence)}`
    this.confidenceTarget.setAttribute('title', `Tillitsnivå: ${percentage}%`)
  }

  updateProvider(provider) {
    if (!this.hasProviderTarget) return
    
    const providerNames = {
      xai_grok: "xAI Grok",
      anthropic_claude: "Anthropic Claude",
      openai_gpt: "OpenAI GPT",
      ollama_local: "Ollama (Lokal)"
    }
    
    this.providerTarget.textContent = providerNames[provider] || provider
    this.providerTarget.setAttribute('title', `AI-leverandør: ${providerNames[provider] || provider}`)
  }

  getConfidenceLevel(confidence) {
    if (confidence >= 0.8) return "high"
    if (confidence >= 0.6) return "medium"
    return "low"
  }

  showWarning(warning) {
    window.showHealthcareNotification("warning", warning, 8000)
  }

  setStatus(type, message) {
    if (!this.hasStatusTarget) return
    
    this.statusTarget.className = `ai3-status ai3-status--${type}`
    this.statusTarget.textContent = message
    this.statusTarget.setAttribute('aria-label', `Status: ${message}`)
  }

  setupAccessibility() {
    // Ensure proper ARIA labels
    this.inputTarget.setAttribute('aria-label', 'Skriv ditt spørsmål til AI-assistenten')
    this.outputTarget.setAttribute('aria-label', 'Samtalehistorikk med AI-assistent')
    this.outputTarget.setAttribute('aria-live', 'polite')
    
    // Add role descriptions
    if (this.hasConfidenceTarget) {
      this.confidenceTarget.setAttribute('aria-label', 'Tillitsnivå for siste AI-respons')
    }
    
    if (this.hasProviderTarget) {
      this.providerTarget.setAttribute('aria-label', 'Gjeldende AI-leverandør')
    }
  }

  bindKeyboardShortcuts() {
    this.inputTarget.addEventListener('keydown', this.handleKeydown.bind(this))
  }

  disableInput() {
    this.inputTarget.disabled = true
    this.inputTarget.setAttribute('aria-busy', 'true')
  }

  enableInput() {
    this.inputTarget.disabled = false
    this.inputTarget.removeAttribute('aria-busy')
  }

  focusInput() {
    this.inputTarget.focus()
  }

  clearInput() {
    this.inputTarget.value = ''
  }

  clearOutput() {
    this.outputTarget.innerHTML = ''
  }

  scrollToBottom() {
    this.outputTarget.scrollTop = this.outputTarget.scrollHeight
  }

  generateSessionId() {
    return 'session_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9)
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