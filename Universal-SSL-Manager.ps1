# Universal SSL Manager - Windows PowerShell 5.1 / WinForms
# Self-signed: local certificate creation, export, renewal, optional IIS binding.
# Public CA: guided ACME workflow; installation to third-party hosting is NOT automatic.
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

function Notice($s) { [System.Windows.Forms.MessageBox]::Show($s,'Universal SSL Manager') | Out-Null }
function Confirm($s) { return ([System.Windows.Forms.MessageBox]::Show($s,'Confirm', 'YesNo','Warning') -eq 'Yes') }
function Log($s) { $log.AppendText("$(Get-Date -Format HH:mm:ss)  $s`r`n") }
function Find-Cert {
  $thumb=$thumbBox.Text.Trim().Replace(' ','').ToUpper()
  if (-not $thumb -or $thumb -notmatch '^[0-9A-F]{40}$') { throw 'Select a certificate from the list first.' }
  $c=Get-Item "Cert:\LocalMachine\My\$thumb" -ErrorAction SilentlyContinue
  if (-not $c) { throw 'Certificate not found in LocalMachine\My.' }
  return $c
}
function Get-HostValue {
  $h=$hostBox.Text.Trim()
  if (-not $h -or $h -match '[\s/:\\]') { throw 'Enter a plain DNS hostname or IPv4 address (without http:// or a port).' }
  return $h
}
function Get-Password($caption) {
  $p=New-Object System.Windows.Forms.Form
  $p.Text=$caption; $p.Size=New-Object System.Drawing.Size(400,155); $p.StartPosition='CenterParent'
  $t=New-Object System.Windows.Forms.TextBox; $t.Location=New-Object System.Drawing.Point(15,15); $t.Width=350; $t.UseSystemPasswordChar=$true
  $ok=New-Object System.Windows.Forms.Button; $ok.Text='OK'; $ok.Location=New-Object System.Drawing.Point(275,55); $ok.DialogResult='OK'
  $p.Controls.AddRange(@($t,$ok)); $p.AcceptButton=$ok
  if ($p.ShowDialog() -ne 'OK' -or $t.Text.Length -lt 12) { throw 'A password of at least 12 characters is required.' }
  return (ConvertTo-SecureString $t.Text -AsPlainText -Force)
}
function Refresh-Certs {
  $certList.Items.Clear()
  Get-ChildItem Cert:\LocalMachine\My | Sort-Object NotAfter -Descending | ForEach-Object {
    $item=New-Object System.Windows.Forms.ListViewItem($_.FriendlyName)
    [void]$item.SubItems.Add($_.Subject)
    [void]$item.SubItems.Add($_.NotAfter.ToString('yyyy-MM-dd'))
    [void]$item.SubItems.Add($_.Thumbprint)
    [void]$certList.Items.Add($item)
  }
}
function Run-Safely([scriptblock]$work) {
  try { & $work } catch { Log "ERROR: $($_.Exception.Message)"; Notice $_.Exception.Message }
}
$form=New-Object System.Windows.Forms.Form
$form.Text='Universal SSL Manager - Local + Hosted Websites'
$form.Size=New-Object System.Drawing.Size(980,850)
$form.MinimumSize=New-Object System.Drawing.Size(980,850)
$form.StartPosition='CenterScreen'
$form.Font=New-Object System.Drawing.Font('Segoe UI',9)
function Label($s,$x,$y,$w=180) {
  $c=New-Object System.Windows.Forms.Label; $c.Text=$s; $c.Location=New-Object System.Drawing.Point($x,$y); $c.Size=New-Object System.Drawing.Size($w,23); $form.Controls.Add($c)
}
function TextBox($x,$y,$w,$value='') {
  $c=New-Object System.Windows.Forms.TextBox; $c.Location=New-Object System.Drawing.Point($x,$y); $c.Size=New-Object System.Drawing.Size($w,25); $c.Text=$value; $form.Controls.Add($c); return $c
}
function Button($s,$x,$y,$w,$action) {
  $c=New-Object System.Windows.Forms.Button; $c.Text=$s; $c.Location=New-Object System.Drawing.Point($x,$y); $c.Size=New-Object System.Drawing.Size($w,34); $c.FlatStyle='System'; $c.Add_Click($action); $form.Controls.Add($c); return $c
}
Label 'Application / hosting' 20 20 145
$appBox=New-Object System.Windows.Forms.ComboBox; $appBox.Location=New-Object System.Drawing.Point(175,17); $appBox.Width=260; $appBox.DropDownStyle='DropDownList'
[void]$appBox.Items.AddRange([object[]]@('IIS (local)','ASP.NET Core / Kestrel','Node.js / React / Angular','WordPress / cPanel','Apache / Nginx','Java / Tomcat','Other / remote'))
$appBox.SelectedIndex=0; $form.Controls.Add($appBox)
Label 'Hostname or IP' 465 20 125
$hostBox=TextBox 590 17 355 '192.168.1.58'
Label 'IIS website' 20 60 145
$siteBox=New-Object System.Windows.Forms.ComboBox
$siteBox.Location=New-Object System.Drawing.Point(175,57)
$siteBox.Width=260
$siteBox.DropDownStyle='DropDownList'
$form.Controls.Add($siteBox)
function Refresh-IISSites {
  $previous=$siteBox.Text
  $siteBox.Items.Clear()
  try {
    Import-Module WebAdministration -ErrorAction Stop
    $names=@(Get-Website -ErrorAction Stop | Select-Object -ExpandProperty Name)
    foreach($name in $names) { [void]$siteBox.Items.Add($name) }
    if($siteBox.Items.Count -gt 0) {
      if($siteBox.Items.Contains($previous)) { $siteBox.SelectedItem=$previous }
      elseif($siteBox.Items.Contains('Testcase')) { $siteBox.SelectedItem='Testcase' }
      else { $siteBox.SelectedIndex=0 }
    }
  } catch { Log "IIS site discovery unavailable: $($_.Exception.Message)" }
}
Label 'HTTPS port' 465 60 125
$portBox=New-Object System.Windows.Forms.NumericUpDown
$portBox.SetBounds(590,56,125,28)
$portBox.Minimum=1; $portBox.Maximum=65535; $portBox.Value=8443
$portBox.ThousandsSeparator=$false
$form.Controls.Add($portBox)
$portBox.BringToFront()
Label 'Certificate type' 20 101 145
$typeBox=New-Object System.Windows.Forms.ComboBox; $typeBox.Location=New-Object System.Drawing.Point(175,98); $typeBox.Width=260; $typeBox.DropDownStyle='DropDownList'
[void]$typeBox.Items.AddRange([object[]]@('Self-signed (local / testing)','Public CA (ACME guidance)')); $typeBox.SelectedIndex=0; $form.Controls.Add($typeBox)
$trustBox=New-Object System.Windows.Forms.CheckBox; $trustBox.Text='Trust self-signed certificate on this PC (development only)'; $trustBox.Location=New-Object System.Drawing.Point(465,99); $trustBox.Size=New-Object System.Drawing.Size(480,24); $form.Controls.Add($trustBox)
Label 'Certificates in LocalMachine\My (select a row to manage)' 20 145 700
$certList=New-Object System.Windows.Forms.ListView; $certList.Location=New-Object System.Drawing.Point(20,172); $certList.Size=New-Object System.Drawing.Size(925,240)
$certList.View='Details'; $certList.FullRowSelect=$true; $certList.MultiSelect=$false
[void]$certList.Columns.Add('Friendly name',220); [void]$certList.Columns.Add('Subject',260); [void]$certList.Columns.Add('Expires',110); [void]$certList.Columns.Add('Thumbprint',310)
$form.Controls.Add($certList)
$thumbBox=TextBox 20 419 925
$thumbBox.ReadOnly=$true
$certList.Add_SelectedIndexChanged({ if($certList.SelectedItems.Count -gt 0) { $thumbBox.Text=$certList.SelectedItems[0].SubItems[3].Text } })
Button 'Create certificate' 20 460 175 {
 Run-Safely {
  if ($typeBox.SelectedIndex -ne 0) { Notice 'Public certificates require CA validation. Click Public CA guide for next steps.'; return }
  $h=Get-HostValue
  if (-not (Confirm "Create a NEW self-signed certificate for $h?")) { return }
  $ipObj=$null
  $isIp=[System.Net.IPAddress]::TryParse($h,[ref]$ipObj)
  if($isIp -and $ipObj.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) { throw 'This version supports IPv4 and DNS hostnames.' }
  $ext=if($isIp) { "2.5.29.17={text}IPAddress=$h" } else { "2.5.29.17={text}DNS=$h" }
  $c=New-SelfSignedCertificate -Type Custom -Subject "CN=$h" -TextExtension @($ext) -KeyAlgorithm RSA -KeyLength 2048 -KeyUsage DigitalSignature,KeyEncipherment -CertStoreLocation 'Cert:\LocalMachine\My' -FriendlyName "UniversalSSL $h" -NotAfter (Get-Date).AddYears(1) -ErrorAction Stop
  if ($trustBox.Checked) {
    if (Confirm 'Trust this self-signed certificate as a ROOT on this PC? Only do this on an approved development machine.') {
      $tmp=Join-Path $env:TEMP ("ussl-"+$c.Thumbprint+'.cer')
      Export-Certificate -Cert $c -FilePath $tmp -Force | Out-Null
      Import-Certificate -FilePath $tmp -CertStoreLocation 'Cert:\LocalMachine\Root' | Out-Null
      Remove-Item $tmp -Force
      Log 'Added certificate to local Trusted Root store.'
    }
  }
  Refresh-Certs; Log "Created certificate: $($c.Thumbprint) for $h"; Notice 'Certificate created. Select it in the list, then install in IIS or export.'
 }
}
$installButton=Button 'Install to IIS' 207 460 175 {
 Run-Safely {
  if ($appBox.Text -ne 'IIS (local)') { throw 'Automatic installation is supported only for local IIS. Export for other server types.' }
  $c=Find-Cert; $h=Get-HostValue; $site=$siteBox.Text.Trim(); $port=0
  if (-not [int]::TryParse($portBox.Text,[ref]$port) -or $port -lt 1 -or $port -gt 65535) { throw 'Invalid HTTPS port.' }
  Import-Module WebAdministration -ErrorAction Stop
  if (-not $site -or -not (Test-Path "IIS:\Sites\$site")) { throw "Select an existing IIS website from the dropdown." }
  $ipObj=$null; $isIp=[System.Net.IPAddress]::TryParse($h,[ref]$ipObj)
  $bindIP=if($isIp){$h}else{'*'}
  $bindingInfo="${bindIP}:${port}:"
  $all=Get-WebBinding -Protocol https
  if($all | Where-Object { $_.bindingInformation -eq $bindingInfo }) { throw "This site/IP/port already has an HTTPS binding. Do not install again. Use Apply HTTPS port to change its port, or inspect the binding in IIS Manager." }
  $plannedSslPath=if($bindIP -eq "*"){"IIS:\SslBindings\0.0.0.0!${port}"}else{"IIS:\SslBindings\${bindIP}!${port}"}
  if(Test-Path $plannedSslPath) { throw "An SSL mapping already exists for this IP and port. No changes made. Inspect the binding in IIS Manager." }
  if (-not (Confirm "Install certificate $($c.Thumbprint) on IIS site '$site' at ${bindIP}:$port (no hostname)?`nThis binds a single IP/port, so confirm it is dedicated to this site.")) { return }
  New-WebBinding -Name $site -Protocol https -IPAddress $bindIP -Port $port -ErrorAction Stop
  try { $sslPath="IIS:\SslBindings\${bindIP}!${port}"; if($bindIP -eq '*'){$sslPath="IIS:\SslBindings\0.0.0.0!${port}"};
    $c | New-Item $sslPath -Force -ErrorAction Stop | Out-Null
  } catch {
    Remove-WebBinding -Name $site -Protocol https -IPAddress $bindIP -Port $port -ErrorAction SilentlyContinue
    throw "SSL assignment failed; attempted binding rollback: $($_.Exception.Message)"
  }
  Log "IIS HTTPS configured on $site : $bindingInfo"; Notice "IIS binding installed. Test https://${h}:$port. Firewall access is not changed."
 }
}
Button 'Export .CER / .PFX' 394 460 175 {
 Run-Safely {
  $c=Find-Cert
  $dlg=New-Object System.Windows.Forms.SaveFileDialog; $dlg.Filter='Public certificate (*.cer)|*.cer|PFX with private key (*.pfx)|*.pfx'; $dlg.FileName='certificate.cer'
  if($dlg.ShowDialog() -ne 'OK') { return }
  if($dlg.FilterIndex -eq 1) { Export-Certificate -Cert $c -FilePath $dlg.FileName -Force -ErrorAction Stop | Out-Null }
  else { $pw=Get-Password 'PFX password (minimum 12 characters)'; Export-PfxCertificate -Cert $c -FilePath $dlg.FileName -Password $pw -ErrorAction Stop | Out-Null }
  Log "Exported to $($dlg.FileName)"; Notice 'Export completed. Protect PFX files: they contain the private key.'
 }
}
Button 'Renew / replace' 581 460 175 {
 Run-Safely {
  $c=Find-Cert
  Notice "Self-signed renewal creates a new certificate; it does not update existing server bindings. For a safe replacement, create a new certificate, export/install it, verify HTTPS, then remove the old one. Public CA renewals must be performed through your ACME client or hosting provider."
 }
}
Button 'Remove certificate' 768 460 177 {
 Run-Safely {
  $c=Find-Cert
  Import-Module WebAdministration -ErrorAction SilentlyContinue
  if (Get-Command Get-WebBinding -ErrorAction SilentlyContinue) {
    $uses=@(Get-WebBinding -Protocol https | Where-Object { $_.certificateHash -and (($_.certificateHash -replace '\s','').ToUpper() -eq $c.Thumbprint.ToUpper()) })
    if($uses.Count -gt 0) { throw 'Certificate is referenced by IIS HTTPS binding(s). Remove/reassign those bindings manually first. No certificate deleted.' }
  }
  if(-not (Confirm "Permanently delete certificate $($c.Thumbprint) from Personal store AND local Root trust (if present)?`nPrivate key may also be removed. Ensure no non-IIS service uses it.")) { return }
  $root="Cert:\LocalMachine\Root\$($c.Thumbprint)"
  if(Test-Path $root) { Remove-Item $root -ErrorAction Stop }
  Remove-Item "Cert:\LocalMachine\My\$($c.Thumbprint)" -DeleteKey -ErrorAction Stop
  Refresh-Certs; $thumbBox.Clear(); Log 'Certificate deleted.'
 }
}
Button 'Refresh certificates' 20 510 175 { Run-Safely { Refresh-Certs; if($appBox.SelectedIndex -eq 0){Refresh-IISSites}; Log 'Certificate list refreshed.' } }
Button 'Public CA guide' 207 510 175 {
 Notice "PUBLIC SSL (Let's Encrypt):`n`n1. Use a domain you control (not a private LAN IP).`n2. Choose DNS-01 TXT validation, or HTTP-01 if port 80 is publicly reachable.`n3. For WordPress/cPanel, use your host's SSL/TLS or AutoSSL controls first.`n4. For Windows IIS, use win-acme (https://www.win-acme.com/) for ACME issuance/renewal.`n5. For Apache/Nginx, use Certbot on the actual server.`n6. For managed WordPress, use the hosting provider's SSL tools.`n`nThis app does not claim to remotely install or renew public certificates."
}
Button 'IIS binding guide' 394 510 175 {
 Notice 'To remove HTTPS from IIS: IIS Manager > Sites > select site > Bindings > select the exact HTTPS IP/port > Remove. Then Refresh here and delete the certificate only after checking it is unused by other services.'
}
# New controls preserve the original Universal SSL Manager layout.
Button 'Apply HTTPS port' 20 556 175 {
 Run-Safely {
  if($appBox.Text -ne 'IIS (local)') { throw 'Select IIS (local) to manage IIS HTTPS bindings.' }
  Import-Module WebAdministration -ErrorAction Stop
  $site=$siteBox.Text.Trim(); $h=Get-HostValue; $newPort=[int]$portBox.Value
  if(-not $site){ throw 'Choose an IIS website.' }
  $bindings=@(Get-WebBinding -Name $site -Protocol https -ErrorAction Stop)
  if($bindings.Count -eq 0){ throw 'This site has no HTTPS binding yet. Select a certificate and click Install to IIS.' }
  $matching=@($bindings | Where-Object {
    $parts=$_.bindingInformation.Split(':')
    $parts.Count -eq 3 -and $parts[0] -eq $h -and $parts[2] -eq ''
  })
  if($matching.Count -ne 1){ throw 'Cannot uniquely identify an IP-specific HTTPS binding for this site. Check the IIS bindings and hostname/IP field. No changes made.' }
  $old=$matching[0]; $oldInfo=[string]$old.bindingInformation
  $parts=$oldInfo.Split(':'); $bindIP=$parts[0]; $oldPort=[int]$parts[1]
  if($oldPort -eq $newPort){ Notice "HTTPS port $newPort is already configured for this site."; return }
  $hash=([string]$old.certificateHash -replace '\s','').ToUpper()
  if($hash -notmatch '^[0-9A-F]{40}$'){ throw 'Cannot identify the currently bound certificate. No changes made.' }
  $cert=Get-Item "Cert:\LocalMachine\My\$hash" -ErrorAction Stop
  $newInfo="${bindIP}:${newPort}:"
  if(@(Get-WebBinding -Protocol https | Where-Object {$_.bindingInformation -eq $newInfo}).Count -gt 0){ throw "Port $newPort already has an IIS HTTPS binding for this IP. No changes made." }
  $sslPath="IIS:\SslBindings\${bindIP}!${newPort}"
  if(Test-Path $sslPath){ throw "An HTTP.sys SSL certificate mapping already exists for $bindIP`:$newPort. No changes made. Inspect with netsh http show sslcert." }
  if(-not (Confirm "Change HTTPS port for '$site' from $oldPort to $newPort on $bindIP?`n`nCertificate: $hash`nThe existing binding will be retained until the new one is configured.")){ return }
  New-WebBinding -Name $site -Protocol https -IPAddress $bindIP -Port $newPort -ErrorAction Stop
  try {
   $cert | New-Item $sslPath -ErrorAction Stop | Out-Null
  } catch {
   Remove-WebBinding -Name $site -Protocol https -IPAddress $bindIP -Port $newPort -ErrorAction SilentlyContinue
   throw "New SSL mapping failed. Old binding retained. $($_.Exception.Message)"
  }
  try {
   Remove-WebBinding -Name $site -Protocol https -IPAddress $bindIP -Port $oldPort -ErrorAction Stop
  } catch {
   Log "WARNING: Could not remove old port $oldPort. Both HTTPS bindings may remain."
   Notice 'New HTTPS port configured, but old binding removal failed. Review IIS bindings.'
   return
  }
  Log "Changed $site HTTPS port $oldPort -> $newPort using existing certificate $hash."
  Notice "Port changed successfully. Test https://${bindIP}:$newPort. The certificate was reused."
 }
}
Button 'Check Not Secure' 207 556 175 {
 Run-Safely {
  $h=Get-HostValue; $port=0
  if(-not [int]::TryParse($portBox.Text,[ref]$port) -or $port -lt 1 -or $port -gt 65535){ throw 'Enter a valid HTTPS port.' }
  $tcp=New-Object System.Net.Sockets.TcpClient
  $tcp.ReceiveTimeout=7000; $tcp.SendTimeout=7000
  $async=$tcp.BeginConnect($h,$port,$null,$null)
  if(-not $async.AsyncWaitHandle.WaitOne(7000)){ $tcp.Close(); throw "Connection timed out to ${h}:$port" }
  try { $tcp.EndConnect($async) } catch { $tcp.Close(); throw "Cannot connect to ${h}:$port. $($_.Exception.Message)" }
  $script:sslErrors=[System.Net.Security.SslPolicyErrors]::None
  $callback=[System.Net.Security.RemoteCertificateValidationCallback]{ param($sender,$certificate,$chain,$errors) $script:sslErrors=$errors; return $true }
  $stream=New-Object System.Net.Security.SslStream($tcp.GetStream(),$false,$callback)
  try {
   $stream.AuthenticateAsClient($h)
   $remote=New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($stream.RemoteCertificate)
   $san=$remote.Extensions | Where-Object {$_.Oid.Value -eq '2.5.29.17'} | Select-Object -First 1
   $sanText=if($san){$san.Format($true)}else{'MISSING'}
   $trusted=Test-Path "Cert:\LocalMachine\Root\$($remote.Thumbprint)"
   $personal=Test-Path "Cert:\LocalMachine\My\$($remote.Thumbprint)"
   $isIp=$false; $ipObj=$null; $isIp=[System.Net.IPAddress]::TryParse($h,[ref]$ipObj)
   $sanOk=if($isIp){ $sanText -match ('(?i)IP Address\s*=\s*'+[regex]::Escape($h)+'(?![0-9.])') }else{ $sanText -match ('(?i)DNS Name\s*=\s*'+[regex]::Escape($h)+'(?![A-Za-z0-9.-])') }
   $report="HTTPS diagnostic for ${h}:$port`r`n`r`nCertificate served by server:`r`nSubject: $($remote.Subject)`r`nThumbprint: $($remote.Thumbprint)`r`nExpires: $($remote.NotAfter)`r`nSAN: $sanText`r`n`r`nWindows TLS policy errors: $script:sslErrors`r`nSame cert in Personal store: $personal`r`nSame cert in LocalMachine Trusted Root: $trusted`r`nHostname/IP SAN check: $sanOk`r`n`r`n"
   if($script:sslErrors -eq [System.Net.Security.SslPolicyErrors]::None){$report+='Windows TLS validation succeeded. If Chrome still warns, inspect Chrome certificate details and restart the browser.'}
   else {
    $report+='Troubleshooting: Verify the selected IIS binding serves this exact thumbprint. For a self-signed development certificate, only with IT approval, trust the exact certificate on the computer running the browser. Check SAN and expiry. Do not bypass browser warnings.'
   }
   Log "TLS diagnostic ${h}:$port - $script:sslErrors - $($remote.Thumbprint)"
   $out=New-Object System.Windows.Forms.Form; $out.Text='HTTPS Certificate Diagnostic'; $out.Size=New-Object System.Drawing.Size(720,480); $out.StartPosition='CenterParent'
   $txt=New-Object System.Windows.Forms.TextBox; $txt.Multiline=$true; $txt.ReadOnly=$true; $txt.ScrollBars='Both'; $txt.WordWrap=$true; $txt.Dock='Fill'; $txt.Font=New-Object System.Drawing.Font('Consolas',10); $txt.Text=$report
   $out.Controls.Add($txt); [void]$out.ShowDialog($form)
  } finally { if($stream){$stream.Dispose()}; $tcp.Close() }
 }
}
# Fix SSL Trust: use the exact certificate presented by the selected local IIS endpoint.
Button 'Fix SSL Trust' 394 556 175 {
 Run-Safely {
  if($appBox.Text -ne 'IIS (local)') { throw 'Fix SSL Trust is available only for local IIS sites.' }
  $h=Get-HostValue; $port=0
  if(-not [int]::TryParse($portBox.Text,[ref]$port) -or $port -lt 1 -or $port -gt 65535) { throw 'Select a valid HTTPS port.' }
  $localIps=@('127.0.0.1','localhost','::1')
  $localIps+=@(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty IPAddress)
  if($h -notin $localIps) { throw 'Trust installation is restricted to local IP addresses on this Windows machine. Remote sites are never trusted automatically.' }
  Import-Module WebAdministration -ErrorAction Stop
  $site=$siteBox.Text
  if(-not $site) { throw 'Select an IIS website first.' }
  $matching=@(Get-WebBinding -Name $site -Protocol https | Where-Object {
    $p=$_.bindingInformation.Split(':'); $p.Count -ge 3 -and $p[1] -eq [string]$port -and ($p[0] -eq $h -or $p[0] -eq '*')
  })
  if($matching.Count -ne 1) { throw 'Could not uniquely match the selected IIS site, IP and port. Check IIS Bindings before proceeding.' }
  $tcp=New-Object System.Net.Sockets.TcpClient
  $stream=$null
  try {
   $async=$tcp.BeginConnect($h,$port,$null,$null)
   if(-not $async.AsyncWaitHandle.WaitOne(7000)) { throw 'HTTPS connection timed out.' }
   $tcp.EndConnect($async)
   $callback=[System.Net.Security.RemoteCertificateValidationCallback]{ param($sender,$certificate,$chain,$errors) return $true }
   $stream=New-Object System.Net.Security.SslStream($tcp.GetStream(),$false,$callback)
   $stream.AuthenticateAsClient($h)
   $remote=New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($stream.RemoteCertificate)
  } finally { if($stream){$stream.Dispose()}; $tcp.Close() }
  $thumb=$remote.Thumbprint.ToUpper()
  $boundHash=([string]$matching[0].certificateHash -replace '\s','').ToUpper()
  if($boundHash -ne $thumb) { throw 'The certificate served by the endpoint does not match the selected IIS binding. No trust change made.' }
  $local=Get-Item "Cert:\LocalMachine\My\$thumb" -ErrorAction SilentlyContinue
  if(-not $local -or -not $local.HasPrivateKey) { throw 'Presented certificate is not a locally managed certificate with private key. Refusing to trust.' }
  if($remote.NotBefore -gt (Get-Date) -or $remote.NotAfter -le (Get-Date)) { throw 'Certificate is not currently valid. Refusing to trust.' }
  $ipObj=$null; $isIp=[System.Net.IPAddress]::TryParse($h,[ref]$ipObj)
  $san=$remote.Extensions | Where-Object { $_.Oid.Value -eq '2.5.29.17' } | Select-Object -First 1
  $sanText=if($san){$san.Format($true)}else{''}
  if($isIp -and $sanText -notmatch ('(?i)IP Address\s*=\s*'+[regex]::Escape($h)+'(?![0-9.])')) { throw 'IP SAN mismatch. Refusing to trust.' }
  if(-not $isIp -and $sanText -notmatch ('(?i)DNS Name\s*=\s*'+[regex]::Escape($h)+'(?![A-Za-z0-9.-])')) { throw 'DNS SAN mismatch. Refusing to trust.' }
  if($remote.Subject -ne $remote.Issuer) { throw 'Certificate is not self-issued. This action is only for local self-signed development certificates.' }
  if(Test-Path "Cert:\LocalMachine\Root\$thumb") { Notice 'This exact certificate is already in the LocalMachine Trusted Root store. If the browser still shows Not secure, check browser Security tab for active content or certificate errors.'; return }
  $msg="Trust the EXACT self-signed certificate served by this LOCAL IIS site?`n`nSite: $site`nURL: https://${h}:$port`nSubject: $($remote.Subject)`nThumbprint: $thumb`nExpires: $($remote.NotAfter)`n`nThis grants broad trust to this certificate on this computer. Only proceed with IT approval on a development machine."
  if(-not (Confirm $msg)) { return }
  $tmp=Join-Path $env:TEMP ("universal-ssl-trust-"+$thumb+'.cer')
  try {
   Export-Certificate -Cert $local -FilePath $tmp -Force -ErrorAction Stop | Out-Null
   Import-Certificate -FilePath $tmp -CertStoreLocation 'Cert:\LocalMachine\Root' -ErrorAction Stop | Out-Null
  } finally { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
  if(-not (Test-Path "Cert:\LocalMachine\Root\$thumb")) { throw 'Trust import did not complete.' }
  Log "Trusted local IIS certificate $thumb for ${h}:$port"
  Notice 'Certificate trust added successfully. Run Check Not Secure again. If TLS passes but the browser still warns, check the browser Security panel for active content with certificate errors.'
 }
}

Label 'Activity log' 20 610 300
$log=New-Object System.Windows.Forms.TextBox; $log.Multiline=$true; $log.ScrollBars='Vertical'; $log.ReadOnly=$true
$log.Location=New-Object System.Drawing.Point(20,636); $log.Size=New-Object System.Drawing.Size(925,130); $form.Controls.Add($log)

# Context-sensitive fields: do not show IIS-specific fields for other hosting types.
$siteLabel=$form.Controls | Where-Object { $_ -is [System.Windows.Forms.Label] -and $_.Text -eq 'IIS website' } | Select-Object -First 1
$portLabel=$form.Controls | Where-Object { $_ -is [System.Windows.Forms.Label] -and $_.Text -eq 'HTTPS port' } | Select-Object -First 1
$hostLabel=$form.Controls | Where-Object { $_ -is [System.Windows.Forms.Label] -and $_.Text -eq 'Hostname or IP' } | Select-Object -First 1
$detailLabel=New-Object System.Windows.Forms.Label
$detailLabel.Location=New-Object System.Drawing.Point(20,128)
$detailLabel.Size=New-Object System.Drawing.Size(925,24)
$detailLabel.ForeColor=[System.Drawing.Color]::FromArgb(55,85,110)
$form.Controls.Add($detailLabel)

function Update-ApplicationFields {
  $choice=$appBox.Text
  $iis=($choice -eq 'IIS (local)')
  $siteLabel.Visible=$iis; $siteBox.Visible=$iis
  $portLabel.Visible=($iis -or $choice -eq 'ASP.NET Core / Kestrel' -or $choice -eq 'Node.js / React / Angular' -or $choice -eq 'Java / Tomcat' -or $choice -eq 'Other / remote')
  $portBox.Visible=$portLabel.Visible; if($portBox.Visible){ $portBox.BringToFront(); $portLabel.BringToFront() }
  $installButton.Enabled=$iis
  $installButton.Visible=$iis
  $hostLabel.Text=if($choice -eq 'WordPress / cPanel' -or $choice -eq 'Apache / Nginx'){'Website domain'}else{'Hostname or IP'}
  if($iis) {
    if($siteBox.Items.Count -eq 0){ Refresh-IISSites }
    $detailLabel.Text='IIS: choose a site. Edit HTTPS port above and click Apply HTTPS port for existing bindings.'
  } elseif($choice -eq 'WordPress / cPanel') {
    $detailLabel.Text='WordPress: SSL is installed at the host/web server; use hosting SSL tools or export a certificate.'
  } elseif($choice -eq 'Apache / Nginx') {
    $detailLabel.Text='Apache/Nginx: export certificate files and configure TLS on the target server.'
  } elseif($choice -eq 'ASP.NET Core / Kestrel') {
    $detailLabel.Text='Kestrel: export a password-protected PFX and configure the HTTPS endpoint in the app.'
  } elseif($choice -eq 'Node.js / React / Angular') {
    $detailLabel.Text='Node.js: export a PFX or convert to PEM securely; configure the actual web server.'
  } elseif($choice -eq 'Java / Tomcat') {
    $detailLabel.Text='Java/Tomcat: export a PFX (PKCS#12) and configure your Java TLS connector.'
  } else {
    $detailLabel.Text='Custom/remote: generate/export only; remote installation needs provider-specific access.'
  }
  $trustBox.Visible=($typeBox.SelectedIndex -eq 0)
  if($typeBox.SelectedIndex -ne 0) { $trustBox.Checked=$false }
}
$siteBox.Add_SelectedIndexChanged({
 if($appBox.Text -eq 'IIS (local)' -and $siteBox.Text) {
  try {
   $https=@(Get-WebBinding -Name $siteBox.Text -Protocol https -ErrorAction Stop)
   if($https.Count -gt 0) {
    $selected=$https | Where-Object { $_.bindingInformation -like "$($hostBox.Text.Trim()):*:" } | Select-Object -First 1
    if(-not $selected) { $selected=$https | Select-Object -First 1 }
    $parts=$selected.bindingInformation.Split(':')
    if($parts.Count -ge 2 -and [int]$parts[1] -ge 1 -and [int]$parts[1] -le 65535) { $portBox.Value=[decimal]([int]$parts[1]) }
   }
  } catch { Log "Could not detect HTTPS port: $($_.Exception.Message)" }
 }
})
$appBox.Add_SelectedIndexChanged({ Update-ApplicationFields })
$typeBox.Add_SelectedIndexChanged({ Update-ApplicationFields })

$portBox.Visible=$true; $portBox.Enabled=$true; $portBox.BringToFront()
try { Refresh-Certs; Update-ApplicationFields; $portBox.Visible=$true; $portBox.BringToFront(); Log 'Ready. Run as Administrator for create/install/delete.' } catch { Log $_.Exception.Message }
[void]$form.ShowDialog()
