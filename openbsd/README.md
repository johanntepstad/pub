# OpenBSD Security Framework

OpenBSD-specific documentation, configurations, and security hardening materials.

## Security Philosophy

Following OpenBSD principles:
- **Security by default**: Minimal attack surface
- **Proactive security**: Address vulnerabilities before exploitation
- **Correct implementation**: Code correctness over feature completeness
- **Cryptographic excellence**: Strong cryptography integration

## Directory Contents

### Configuration Files
- `pf_advanced.conf` - Packet Filter firewall rules
- `doas_secure.conf` - Privilege escalation configuration
- System hardening configurations
- Network security policies

### Documentation
- Security implementation guides
- Hardening checklists
- Incident response procedures
- Compliance verification steps

### Integration Points
- **Shell Scripts**: Reference to `../sh/deep_nmap_scan.sh`
- **Monitoring**: Structured logging and forensics
- **Network Security**: PF firewall and relayd configuration
- **Application Security**: Privilege separation patterns

## Security Features

### Privilege Management
- **Pledge**: System call restrictions
- **Unveil**: Filesystem access controls
- **doas**: Privilege escalation (sudo alternative)
- **chroot**: Filesystem isolation

### Network Security
- **PF Firewall**: Stateful packet filtering with rate limiting
- **relayd**: Load balancing with SSL termination
- **httpd**: Minimal web server with security headers
- **acme-client**: Automated certificate management

### Monitoring and Forensics
- **Structured Logging**: syslog with centralized collection
- **Intrusion Detection**: Real-time analysis with alerting
- **Evidence Collection**: Tamper-proof audit trails
- **Incident Response**: Automated containment with notifications

## Norwegian Compliance

Security framework includes:
- **GDPR Compliance**: Data protection and privacy
- **Norwegian Law**: Legal requirements adherence
- **Audit Trails**: Immutable logging with cryptographic timestamps
- **Data Residency**: Norwegian server requirements

## References

- Shell utilities: `../sh/`
- Security patterns in master.json
- Rails security configuration
- Business compliance in `../bplans/`