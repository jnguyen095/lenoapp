# One-time setup after installing Flutter: generates android/ and ios/, then patches
#  - Android: INTERNET permission for release builds, allow http:// (LAN server), app label.
#  - iOS: allow http:// to local-network addresses, display name.
# Run:  powershell -ExecutionPolicy Bypass -File tool\setup_platforms.ps1

$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

flutter create --org com.leno --project-name leno_pos --platforms android,ios .
if ($LASTEXITCODE -ne 0) { throw 'flutter create failed' }

$utf8 = New-Object System.Text.UTF8Encoding($false)

# --- Android -----------------------------------------------------------------
$manifest = 'android\app\src\main\AndroidManifest.xml'
$xml = [System.IO.File]::ReadAllText((Resolve-Path $manifest), $utf8)
if ($xml -notmatch 'android.permission.INTERNET') {
    $xml = $xml -replace '(\s*)<application', "`$1<uses-permission android:name=`"android.permission.INTERNET`"/>`$1<application"
}
if ($xml -notmatch 'usesCleartextTraffic') {
    $xml = $xml -replace '<application', "<application`n        android:usesCleartextTraffic=`"true`""
}
$xml = $xml -replace 'android:label="leno_pos"', 'android:label="Leno POS"'
[System.IO.File]::WriteAllText((Resolve-Path $manifest), $xml, $utf8)
Write-Host "Patched $manifest"

# --- iOS ---------------------------------------------------------------------
$plist = 'ios\Runner\Info.plist'
$p = [System.IO.File]::ReadAllText((Resolve-Path $plist), $utf8)
$p = $p -replace '(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)', '${1}Leno POS${2}'
if ($p -notmatch 'NSAppTransportSecurity') {
    $ats = @"
	<key>NSAppTransportSecurity</key>
	<dict>
		<key>NSAllowsLocalNetworking</key>
		<true/>
	</dict>
	<key>NSLocalNetworkUsageDescription</key>
	<string>Connect to the Leno POS server on the shop local network.</string>
</dict>
</plist>
"@
    $p = $p -replace '</dict>\s*</plist>\s*$', $ats
}
[System.IO.File]::WriteAllText((Resolve-Path $plist), $p, $utf8)
Write-Host "Patched $plist"

flutter pub get
Write-Host 'Done. Run: flutter run'
