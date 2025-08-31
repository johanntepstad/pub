# Rails Shared Infrastructure

This directory contains shared Rails components used across all applications (amber, brgen, privcam, bsdports, hjerterom).

## Structure

### Styles
- **modern/**: CSS using flexbox, grid, and modern layout techniques
- **legacy/**: Original CSS for visual parity validation

### Views
- **partials/**: Shared view components
- **layouts/**: Common layout templates
- **components/**: Reusable UI components

### Controllers
- **concerns/**: Shared controller logic
- **authentication/**: Shared auth patterns
- **security/**: Security-related functionality

### Models
- **concerns/**: Shared model behavior
- **validators/**: Custom validation logic
- **utilities/**: Helper classes and modules

## CSS Architecture

### Modern Styles (Default)
```css
/* CSS Variables for consistent theming */
:root {
  --primary-color: hsl(200, 100%, 50%);
  --secondary-color: hsl(45, 100%, 70%);
  --text-color: hsl(0, 0%, 20%);
  --spacing-unit: 0.5rem;
}

/* Flexbox and Grid Layouts */
.layout-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
  gap: var(--spacing-unit);
}
```

### Legacy Compatibility
```css
/* Legacy styles for visual parity validation */
[data-style="legacy"] .component {
  /* Original styling preserved exactly */
}
```

### Toggle Mechanism
```javascript
// Switch between modern and legacy styles
document.documentElement.setAttribute('data-style', 'legacy');
document.documentElement.setAttribute('data-style', 'modern');
```

## Accessibility Features

### WCAG 2.2 AAA Compliance
- Semantic HTML structure
- ARIA labels and descriptions
- Keyboard navigation support
- Screen reader compatibility
- High contrast ratio (7:1 minimum)

### Internationalization
- Norwegian (nb) primary locale
- English (en) fallback
- Locale-specific formatting
- Cultural adaptation patterns

## Usage

### Including Shared Styles
```erb
<!-- In application layout -->
<%= stylesheet_link_tag 'rails/shared/styles/modern/application' %>
```

### Using Shared Partials
```erb
<!-- In app views -->
<%= render 'rails/shared/views/partials/header' %>
<%= render 'rails/shared/views/partials/footer' %>
```

### Implementing Shared Concerns
```ruby
# In controllers
include Rails::Shared::Controllers::Authentication
include Rails::Shared::Controllers::Security

# In models  
include Rails::Shared::Models::Auditable
include Rails::Shared::Models::Sluggable
```