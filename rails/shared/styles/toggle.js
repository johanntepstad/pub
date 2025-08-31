/**
 * CSS Style Toggle Utility
 * Provides functionality to switch between modern and legacy CSS styles
 * for visual parity validation during migration
 */

class StyleToggle {
  constructor() {
    this.currentStyle = this.getCurrentStyle();
    this.init();
  }

  /**
   * Initialize the style toggle system
   */
  init() {
    this.createToggleButton();
    this.applyStyle(this.currentStyle);
    this.bindEvents();
  }

  /**
   * Get current style from localStorage or default to modern
   */
  getCurrentStyle() {
    return localStorage.getItem('style-preference') || 'modern';
  }

  /**
   * Set the current style and persist preference
   */
  setCurrentStyle(style) {
    this.currentStyle = style;
    localStorage.setItem('style-preference', style);
    this.applyStyle(style);
  }

  /**
   * Apply the specified style to the document
   */
  applyStyle(style) {
    document.documentElement.setAttribute('data-style', style);
    this.updateToggleButton();
    this.dispatchStyleChangeEvent(style);
  }

  /**
   * Toggle between modern and legacy styles
   */
  toggle() {
    const newStyle = this.currentStyle === 'modern' ? 'legacy' : 'modern';
    this.setCurrentStyle(newStyle);
  }

  /**
   * Create the toggle button UI
   */
  createToggleButton() {
    // Check if button already exists
    if (document.getElementById('style-toggle-btn')) {
      return;
    }

    const button = document.createElement('button');
    button.id = 'style-toggle-btn';
    button.className = 'style-toggle-btn';
    button.setAttribute('aria-label', 'Toggle between modern and legacy styles');
    button.setAttribute('title', 'Switch CSS styles for validation');
    
    // Position the button fixed in top-right corner
    Object.assign(button.style, {
      position: 'fixed',
      top: '20px',
      right: '20px',
      zIndex: '9999',
      padding: '8px 12px',
      backgroundColor: 'var(--color-primary, #007acc)',
      color: 'white',
      border: 'none',
      borderRadius: '4px',
      fontSize: '12px',
      fontWeight: '600',
      cursor: 'pointer',
      boxShadow: '0 2px 4px rgba(0,0,0,0.2)',
      transition: 'all 0.2s ease'
    });

    button.addEventListener('click', () => this.toggle());
    
    // Add hover effects
    button.addEventListener('mouseenter', () => {
      button.style.backgroundColor = 'var(--color-primary-dark, #005999)';
    });
    
    button.addEventListener('mouseleave', () => {
      button.style.backgroundColor = 'var(--color-primary, #007acc)';
    });

    document.body.appendChild(button);
  }

  /**
   * Update the toggle button text and state
   */
  updateToggleButton() {
    const button = document.getElementById('style-toggle-btn');
    if (button) {
      button.textContent = `Style: ${this.currentStyle}`;
      button.setAttribute('aria-label', 
        `Current style: ${this.currentStyle}. Click to switch to ${this.currentStyle === 'modern' ? 'legacy' : 'modern'} style`
      );
    }
  }

  /**
   * Bind keyboard shortcuts and other events
   */
  bindEvents() {
    // Keyboard shortcut: Ctrl+Shift+S to toggle styles
    document.addEventListener('keydown', (event) => {
      if (event.ctrlKey && event.shiftKey && event.key === 'S') {
        event.preventDefault();
        this.toggle();
      }
    });

    // Listen for style preference changes from other tabs
    window.addEventListener('storage', (event) => {
      if (event.key === 'style-preference') {
        this.currentStyle = event.newValue || 'modern';
        this.applyStyle(this.currentStyle);
      }
    });
  }

  /**
   * Dispatch custom event when style changes
   */
  dispatchStyleChangeEvent(style) {
    const event = new CustomEvent('stylechange', {
      detail: { style, previous: this.currentStyle === 'modern' ? 'legacy' : 'modern' }
    });
    document.dispatchEvent(event);
  }

  /**
   * Remove the toggle button (for cleanup)
   */
  remove() {
    const button = document.getElementById('style-toggle-btn');
    if (button) {
      button.remove();
    }
  }

  /**
   * Get validation information for current styles
   */
  getValidationInfo() {
    return {
      currentStyle: this.currentStyle,
      modernStylesLoaded: this.isStylesheetLoaded('modern'),
      legacyStylesLoaded: this.isStylesheetLoaded('legacy'),
      toggleAvailable: !!document.getElementById('style-toggle-btn')
    };
  }

  /**
   * Check if specific stylesheet is loaded
   */
  isStylesheetLoaded(type) {
    const stylesheets = Array.from(document.styleSheets);
    return stylesheets.some(sheet => 
      sheet.href && sheet.href.includes(`styles/${type}/`)
    );
  }
}

// Auto-initialize when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => {
    window.styleToggle = new StyleToggle();
  });
} else {
  window.styleToggle = new StyleToggle();
}

// Export for use in Rails UJS or other contexts
if (typeof module !== 'undefined' && module.exports) {
  module.exports = StyleToggle;
}

// Usage examples:
// window.styleToggle.toggle() - Toggle between styles
// window.styleToggle.setCurrentStyle('legacy') - Set specific style
// window.styleToggle.getValidationInfo() - Get validation status

// Event listener example:
// document.addEventListener('stylechange', (event) => {
//   console.log(`Style changed to: ${event.detail.style}`);
// });