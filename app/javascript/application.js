// Hotwire Application with Stimulus controllers for healthcare platform
import { Application } from "@hotwired/stimulus"
import { definitionsFromContext } from "@hotwired/stimulus-webpack-helpers"

// Core Stimulus application
const application = Application.start()

// Configure Stimulus development experience
application.debug = false
window.Stimulus = application

// Auto-load all Stimulus controllers
const context = require.context("./controllers", true, /\.js$/)
application.load(definitionsFromContext(context))

// Healthcare platform specific configurations
application.handleError = (error, message, detail) => {
  console.error(`Stimulus Error: ${message}`, error)
  
  // Report to error tracking service
  if (window.healthcareErrorTracker) {
    window.healthcareErrorTracker.captureException(error, {
      tags: { component: "stimulus" },
      extra: { message, detail }
    })
  }
  
  // Show user-friendly error for critical failures
  if (error.name === "NetworkError" || error.name === "TypeError") {
    showHealthcareNotification("warning", "En feil oppstod. Prøv igjen senere.")
  }
}

// Global healthcare platform utilities
window.HealthcarePlatform = {
  // Norwegian localization helpers
  formatCurrency: (amount) => {
    return new Intl.NumberFormat('nb-NO', {
      style: 'currency',
      currency: 'NOK'
    }).format(amount)
  },
  
  formatDate: (date) => {
    return new Intl.DateTimeFormat('nb-NO', {
      dateStyle: 'medium',
      timeZone: 'Europe/Oslo'
    }).format(new Date(date))
  },
  
  formatTime: (date) => {
    return new Intl.DateTimeFormat('nb-NO', {
      timeStyle: 'short',
      timeZone: 'Europe/Oslo'
    }).format(new Date(date))
  },
  
  // Emergency contact helper
  callEmergency: (type = 'medical') => {
    const numbers = {
      medical: '113',
      fire: '110', 
      police: '112',
      poison: '22591300'
    }
    
    if (confirm(`Ring ${numbers[type]}?`)) {
      window.location.href = `tel:${numbers[type]}`
    }
  },
  
  // Accessibility helpers
  announceToScreenReader: (message) => {
    const announcement = document.createElement('div')
    announcement.setAttribute('aria-live', 'polite')
    announcement.setAttribute('aria-atomic', 'true')
    announcement.className = 'sr-only'
    announcement.textContent = message
    
    document.body.appendChild(announcement)
    setTimeout(() => document.body.removeChild(announcement), 1000)
  },
  
  // WCAG 2.2 AAA compliance helpers
  checkContrast: (foreground, background) => {
    // Implementation for contrast ratio checking
    const getLuminance = (color) => {
      const rgb = parseInt(color.slice(1), 16)
      const r = (rgb >> 16) & 0xff
      const g = (rgb >> 8) & 0xff
      const b = (rgb >> 0) & 0xff
      
      const sRGB = [r, g, b].map(c => {
        c = c / 255
        return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4)
      })
      
      return 0.2126 * sRGB[0] + 0.7152 * sRGB[1] + 0.0722 * sRGB[2]
    }
    
    const l1 = getLuminance(foreground)
    const l2 = getLuminance(background)
    const ratio = (Math.max(l1, l2) + 0.05) / (Math.min(l1, l2) + 0.05)
    
    return {
      ratio: ratio,
      aaaNormal: ratio >= 7,
      aaaLarge: ratio >= 4.5,
      aaNormal: ratio >= 4.5,
      aaLarge: ratio >= 3
    }
  }
}

// Global notification system
function showHealthcareNotification(type, message, duration = 5000) {
  const notification = document.createElement('div')
  notification.className = `healthcare-notification healthcare-notification--${type}`
  notification.setAttribute('role', type === 'error' ? 'alert' : 'status')
  notification.setAttribute('aria-live', 'polite')
  
  const icon = type === 'success' ? '✓' : type === 'warning' ? '⚠' : type === 'error' ? '✕' : 'ℹ'
  
  notification.innerHTML = `
    <div class="healthcare-notification__content">
      <span class="healthcare-notification__icon" aria-hidden="true">${icon}</span>
      <span class="healthcare-notification__message">${message}</span>
      <button class="healthcare-notification__close" aria-label="Lukk varsel">×</button>
    </div>
  `
  
  // Add to page
  const container = document.querySelector('.healthcare-notifications') || createNotificationContainer()
  container.appendChild(notification)
  
  // Auto-remove after duration
  const timer = setTimeout(() => removeNotification(notification), duration)
  
  // Manual close handler
  notification.querySelector('.healthcare-notification__close').addEventListener('click', () => {
    clearTimeout(timer)
    removeNotification(notification)
  })
  
  // Announce to screen readers
  window.HealthcarePlatform.announceToScreenReader(message)
  
  return notification
}

function createNotificationContainer() {
  const container = document.createElement('div')
  container.className = 'healthcare-notifications'
  container.setAttribute('aria-label', 'Systemvarsler')
  document.body.appendChild(container)
  return container
}

function removeNotification(notification) {
  notification.style.transform = 'translateX(100%)'
  notification.style.opacity = '0'
  setTimeout(() => {
    if (notification.parentNode) {
      notification.parentNode.removeChild(notification)
    }
  }, 300)
}

// Export for testing
window.showHealthcareNotification = showHealthcareNotification

export { application }