# Erzeugt die Testversion für Tester: dist\HeroLaneWars-Test-v<Version>.zip
# Aufruf: powershell -ExecutionPolicy Bypass -File build-testversion.ps1
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$html = Get-Content (Join-Path $root 'index.html') -Raw -Encoding UTF8
if ($html -notmatch "const VERSION = '([^']+)'") { throw 'VERSION in index.html nicht gefunden' }
$ver = $Matches[1]
$name = "HeroLaneWars-Test-v$ver"
$dist = Join-Path $root 'dist'
$dir = Join-Path $dist $name
if (Test-Path $dir) { Remove-Item $dir -Recurse -Force }
New-Item -ItemType Directory -Path $dir | Out-Null

# Testfenster (F2) für Tester ausschalten
$out = $html -replace 'debug: true,', 'debug: false,'
if ($out -eq $html) { Write-Warning 'debug: true, nicht gefunden – Testfenster bleibt evtl. aktiv' }
[IO.File]::WriteAllText((Join-Path $dir 'index.html'), $out, (New-Object Text.UTF8Encoding($false)))

$readme = @"
Hero Lane Wars - Testversion v$ver

STARTEN
Die Datei index.html per Doppelklick öffnen (Chrome, Edge oder Firefox am PC).
Nichts installieren, kein Internet nötig.

WORUM GEHT ES
Dein Held verteidigt deine Lane gegen Monsterwellen. Du schickst Monster zum Gegner (Bot),
das erhöht dein Einkommen. Wer zuerst alle Leben verliert, verliert. Etwa 15 Minuten pro Partie.

STEUERUNG
Rechtsklick: laufen / angreifen    Q W E R: Skills (Mauszeiger = Ziel)
Shift + Taste: Skillpunkt vergeben  B: Backport zur Basis   F: Heiltrank
Z X C V N: Monster senden          P / Esc: Pause           Tab: dem Gegner zuschauen
Einkaufen geht nur in der Basis (links).

FEEDBACK
Im Spiel oben auf "Feedback" klicken, ausfüllen und "In Zwischenablage kopieren" (oder als Datei speichern).
Version und Spielstand werden automatisch angehängt. Bitte weiterschicken an: den Projektleiter.

Besonders interessiert uns:
- Wann war unklar, was man tun soll?
- Welche Schwierigkeitsstufe war für dich passend?
- Was hat genervt oder ist kaputt gegangen?
"@
[IO.File]::WriteAllText((Join-Path $dir 'LIESMICH.txt'), $readme, (New-Object Text.UTF8Encoding($true)))

$zip = Join-Path $dist "$name.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path $dir -DestinationPath $zip
Write-Host "Fertig: $zip"
