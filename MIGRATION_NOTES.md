# Legacy Materials Migration Notes

## Migration Overview

This document outlines the intelligent restoration of legacy materials by distributing content from `__OLD_BACKUPS/` into the existing top-level structure.

## Directory Structure Created

### Target Directories
- **rails/**: All Rails application code and app-specific assets
  - `rails/amber/`: Amber application (fashion/style management)
  - `rails/brgen/`: Brgen application (social features)
  - `rails/privcam/`: PrivCam application (privacy-focused camera)
  - `rails/bsdports/`: BSD Ports management
  - `rails/hjerterom/`: Hjerterom application (personal spaces)
  - `rails/shared/`: Shared Rails infrastructure

- **ai3/**: AI³ content and orchestration framework
- **bplans/**: Business plan documents and strategic content
- **postpro/**: Post-processing pipelines and assets
- **sh/**: Shell utilities and scripts
- **openbsd/**: OpenBSD-specific documentation and configurations

### Rails Shared Infrastructure
- `rails/shared/styles/modern/`: Modernized CSS using flexbox and CSS grid
- `rails/shared/styles/legacy/`: Original legacy CSS for reference
- `rails/shared/views/`: Shared view partials and layouts
- `rails/shared/controllers/`: Shared controller logic
- `rails/shared/models/`: Shared model concerns

## Migration Mapping

### Files to be Migrated (when __OLD_BACKUPS/ is available)

| Source | Target | Description |
|--------|--------|-------------|
| `__OLD_BACKUPS/amber/` | `rails/amber/` | Amber application files |
| `__OLD_BACKUPS/ai33/` | `ai3/` | AI³ framework and tools |
| `__OLD_BACKUPS/MEGA_ALL_BPLANS.md` | `bplans/` | Business plan documentation |
| `__OLD_BACKUPS/MEGA_ALL_APPS.md` | `bplans/` | Application overview |
| `__OLD_BACKUPS/deep_nmap_scan.sh` | `sh/` | Network scanning utility |

## CSS Modernization

### Legacy CSS Families
- **bsdports**: Original BSD ports styling
- **BRGEN_OLD***: Legacy Brgen application styles  
- **BRGEN_ANCIENT***: Ancient Brgen styling patterns

### Modernization Strategy
1. **Preserve Visual Fidelity**: Pixel-perfect recreation using modern CSS
2. **CSS Variables**: Centralized color and spacing systems
3. **Flexbox & Grid**: Modern layout techniques
4. **Toggle Mechanism**: Switch between legacy and modern styles for validation

### Toggle Implementation
```html
<!-- Modern styles (default) -->
<html data-style="modern">

<!-- Legacy styles for validation -->
<html data-style="legacy">
```

## Rails Views Structure

### Generated Views for Each App
Each Rails application includes standard RESTful views:
- **Index**: List view with pagination and filtering
- **Show**: Detail view with full resource display
- **New**: Creation form with validation
- **Edit**: Update form with pre-populated data

### Accessibility Features
- Semantic HTML structure
- ARIA labels and descriptions
- Keyboard navigation support
- Screen reader compatibility
- WCAG 2.2 AAA compliance target

### Internationalization
- **Norwegian (nb)**: Primary locale
- **English (en)**: Fallback locale
- Localized content for Norwegian business compliance

## Configuration Management

### master.json Integration
The central configuration file coordinates:
- Application list and versions
- CSS style selection (modern/legacy)
- OpenBSD deployment targets
- AI provider configurations
- Gem version management

### Rails Integration
Applications read shared configuration via:
- Environment variables
- Rails initializers
- Shared configuration concerns

## Validation Checklist

### Pre-Migration
- [ ] Backup existing configuration
- [ ] Document current application state
- [ ] Test baseline functionality

### Post-Migration
- [ ] Verify all files moved correctly
- [ ] Test Rails applications load
- [ ] Validate CSS visual parity
- [ ] Confirm accessibility compliance
- [ ] Test internationalization

### CSS Validation
- [ ] Toggle between modern and legacy styles
- [ ] Screenshot comparison tests
- [ ] Cross-browser validation
- [ ] Performance impact assessment

## Implementation Status

### Completed
- [x] Target directory structure created
- [x] Rails shared infrastructure setup
- [x] Application configuration framework
- [x] Basic Rails views scaffold prepared

### In Progress
- [ ] Rails view generation for each app
- [ ] CSS modernization framework
- [ ] master.json integration
- [ ] i18n locale setup

### Pending
- [ ] Legacy materials migration (when available)
- [ ] CSS visual parity validation
- [ ] Performance optimization
- [ ] Documentation completion

## Notes

- **No __OLD_BACKUPS/ found**: Structure prepared for future migration
- **Rails 8 Ready**: Modern Rails application with latest features
- **Norwegian Compliance**: Timezone, locale, and business requirements configured
- **Security First**: SSL, session, and middleware configurations applied

## Usage

### Switching CSS Styles
```javascript
// Toggle to legacy styles
document.documentElement.setAttribute('data-style', 'legacy');

// Toggle to modern styles  
document.documentElement.setAttribute('data-style', 'modern');
```

### Running Applications
```bash
# Start development server
bin/rails server

# Run tests
bin/rails test

# Lint code
bin/rubocop
```

Last updated: 2025-01-15