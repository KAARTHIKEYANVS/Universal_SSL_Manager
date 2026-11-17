Universal SSL Manager - HTTPS Port Field Update

Double-click Launch.vbs and approve the Windows UAC prompt.

IIS: select website, check Hostname or IP, edit HTTPS port in the visible numeric field, and click Apply HTTPS port. This changes the existing IP-specific binding and reuses its certificate.

For first-time HTTPS installation, create/select a certificate, set the desired port, then click Install to IIS. Do not click Install to IIS repeatedly for an existing binding.

Safety: only IP-specific bindings without hostnames are automatically modified. Existing port conflicts and SSL mappings block changes. Other app types retain certificate export/guidance features; remote installation and automatic public CA renewal are not implemented.

The Fix SSL Trust feature does not fix browser active content that was allowed with certificate errors.

Windows PowerShell 5.1 and IIS WebAdministration module required for IIS management. Run on a test system first.
