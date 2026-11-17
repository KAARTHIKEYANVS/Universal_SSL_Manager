# Universal SSL Manager

A user-friendly Windows desktop application for simplifying SSL certificate management across local development and web hosting environments.

Universal SSL Manager provides a graphical interface for generating self-signed certificates, managing HTTPS configurations, and troubleshooting SSL trust issues without requiring complex PowerShell commands.

### Key Features

- **SSL Certificate Generation** — Create self-signed SSL certificates for local IP addresses and domains.
- **IIS Integration** — Automatically discover IIS websites and configure HTTPS bindings.
- **HTTPS Port Management** — Configure and update HTTPS ports directly from the application.
- **SSL Trust Management** — Diagnose certificate trust issues and optionally trust verified local development certificates.
- **SSL Diagnostics** — Check certificate validity, expiration, hostname/IP matching, and TLS errors.
- **Certificate Export** — Export certificates in CER and password-protected PFX formats.
- **Certificate Management** — View, replace, and remove certificates with safety checks.
- **Dynamic Interface** — Display relevant fields based on the selected application or hosting type.
- **Administrator Elevation** — Launch with Windows administrator permissions through UAC.

### Supported Environments

- Microsoft IIS
- ASP.NET Core / Kestrel
- Node.js / React / Angular
- WordPress / cPanel
- Apache / Nginx
- Java / Tomcat
- Custom applications

**Note:** Automated certificate installation is primarily supported for local IIS. Other environments use certificate export and setup guidance. Publicly trusted certificate issuance and automatic renewal require additional tooling.

### Requirements

- Windows 10/11 or Windows Server
- Windows PowerShell 5.1
- Administrator permissions for certificate installation
- IIS installed for IIS-specific features

### Security

Self-signed certificates are intended for local development and testing. Trust certificates only on authorized devices, and use publicly trusted certificates or an organization-approved certificate authority for production environments.
