# Shell Utilities Directory

Collection of shell scripts and automation utilities, with particular focus on OpenBSD compatibility.

## Planned Contents

### Network Security Tools
- `deep_nmap_scan.sh` - Comprehensive network scanning utility (from __OLD_BACKUPS/)
- Network monitoring and analysis scripts
- Security assessment automation

### Development Utilities  
- Enhanced tree display scripts
- Comprehensive linting automation
- Documentation generation tools
- Deployment automation

### OpenBSD Integration
- Scripts designed for OpenBSD security model
- Pledge and unveil compatibility
- doas integration for privilege management
- System hardening automation

## Usage Guidelines

### Security Considerations
All scripts in this directory:
- Follow OpenBSD security principles
- Use minimal required privileges
- Include error handling and logging
- Support both interactive and automated execution

### File Permissions
- Executable scripts: `chmod +x script_name.sh`
- Security-sensitive scripts: Restricted permissions
- Documentation: Standard read permissions

## Cross-Reference

- Related OpenBSD configurations: `../openbsd/`
- Security framework documentation: See master.json
- Monitoring and forensics: Integrated with security infrastructure

## Migration Status

Awaiting migration of `deep_nmap_scan.sh` and other utilities from `__OLD_BACKUPS/`.