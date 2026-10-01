$root = $PSScriptRoot
$l = New-Object System.Net.HttpListener
$l.Prefixes.Add('http://localhost:8123/')
$l.Start()
while ($l.IsListening) {
  $c = $l.GetContext()
  $p = $c.Request.Url.LocalPath.TrimStart('/'); if ($p -eq '') { $p = 'index.html' }
  # Nur für den Regelwerk-Export: POST /save-regelwerk schreibt genau regelwerk\daten.json (sonst nichts)
  # Golden Values fuer den Godot-Szenario-Runner: POST /save-golden schreibt genau regelwerk\golden-skills.json
  if ($c.Request.HttpMethod -eq 'POST' -and $p -eq 'save-golden') {
    $sr = New-Object IO.StreamReader($c.Request.InputStream, [Text.Encoding]::UTF8)
    $body = $sr.ReadToEnd(); $sr.Close()
    $dir = Join-Path $root 'regelwerk'; if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    [IO.File]::WriteAllText((Join-Path $dir 'golden-skills.json'), $body, (New-Object Text.UTF8Encoding($false)))
    $c.Response.StatusCode = 200; $c.Response.Close(); continue
  }
  if ($c.Request.HttpMethod -eq 'POST' -and $p -eq 'save-regelwerk') {
    $sr = New-Object IO.StreamReader($c.Request.InputStream, [Text.Encoding]::UTF8)
    $body = $sr.ReadToEnd(); $sr.Close()
    $dir = Join-Path $root 'regelwerk'; if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    [IO.File]::WriteAllText((Join-Path $dir 'daten.json'), $body, (New-Object Text.UTF8Encoding($false)))
    $c.Response.StatusCode = 200; $c.Response.Close(); continue
  }
  $f = Join-Path $root $p
  if (Test-Path $f -PathType Leaf) {
    $b = [IO.File]::ReadAllBytes($f)
    $c.Response.ContentType = 'text/html; charset=utf-8'
    $c.Response.OutputStream.Write($b, 0, $b.Length)
  } else { $c.Response.StatusCode = 404 }
  $c.Response.Close()
}
