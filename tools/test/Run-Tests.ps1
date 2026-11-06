# Runs all checks for Update-LatestVideo.ps1 in one go.
# Start a local server in the repo root first:  python3 -m http.server 8765
$ErrorActionPreference = 'Stop'
$script = Join-Path $PSScriptRoot '..' 'Update-LatestVideo.ps1'
$tmp = Join-Path ([IO.Path]::GetTempPath()) "latest-test-$PID"
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
$base = 'http://127.0.0.1:8765'
$fails = 0
function Check($name, [bool]$ok, $detail) {
    if ($ok) { Write-Host "PASS  $name" } else { Write-Host "FAIL  $name  $detail"; $script:fails++ }
}

# 1. Fixture feed: skips the Short, keeps æøå and quotes, valid JSON
$out = Join-Path $tmp 'one.json'
& $script -FeedUrl "$base/tools/test/feed-fixture.xml" -Path $out -RetryWaits 0 -FallbackUrl "$base/nope.json" -ThumbnailBaseUrl "$base/tools/test/vi" | Out-Null
$j = Get-Content $out -Raw | ConvertFrom-Json
Check 'fixture: picks regular video, skips Short' ($j.id -eq 'SVLeErWYejo') $j.id
Check 'fixture: æøå and quotes survive' ($j.title -eq 'Run AI Locally for FREE (No Cloud Required) – æøå & "quotes"') $j.title
Check 'fixture: published normalised to UTC' ($j.published -eq '2026-10-30T15:00:00Z') $j.published
Check 'fixture: source rss' ($j.source -eq 'rss') $j.source
$bytes = [IO.File]::ReadAllBytes($out)
Check 'fixture: UTF-8 without BOM' (-not ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB)) ''
$thumb = Join-Path $tmp 'latest-SVLeErWYejo.jpg'
Check 'fixture: thumbnail self-hosted next to json' ((Test-Path $thumb) -and $j.thumbnail -eq $true) "$($j.thumbnail)"
Check 'fixture: no .part leftovers' (-not (Get-ChildItem $tmp -Filter '*.part')) ''

# 1b. Hostile/odd feed: unicode id rejected, bad date tolerated, newlines stripped, non-JPEG thumbnail refused
$outB = Join-Path $tmp 'bad.json'
& $script -FeedUrl "$base/tools/test/feed-fixture-bad.xml" -Path $outB -RetryWaits 0 -FallbackUrl "$base/nope.json" -ThumbnailBaseUrl "$base/tools/test/vi" 3>$null | Out-Null
$jb = Get-Content $outB -Raw | ConvertFrom-Json
Check 'bad feed: unicode id skipped, next valid id used' ($jb.id -eq 'Abc_DEF-123') $jb.id
Check 'bad feed: newline removed from title' ($jb.title -eq 'Line one ::warning::line two') $jb.title
Check 'bad feed: unparseable date becomes null' ($null -eq $jb.published) "$($jb.published)"
Check 'bad feed: non-JPEG thumbnail refused' ($jb.thumbnail -eq $false -and -not (Test-Path (Join-Path $tmp 'latest-Abc_DEF-123.jpg'))) "$($jb.thumbnail)"

# 2. Feed down + fallback down: no file, no crash
$out2 = Join-Path $tmp 'two.json'
& $script -FeedUrl "$base/missing-feed.xml" -Path $out2 -RetryWaits 0, 1 -FallbackUrl "$base/nope.json" 3>$null | Out-Null
Check 'feed+fallback down: writes nothing' (-not (Test-Path $out2)) ''

# 3. Feed down + live site up: re-uses live latest.json
$out3 = Join-Path $tmp 'three.json'
& $script -FeedUrl "$base/missing-feed.xml" -Path $out3 -RetryWaits 0 -FallbackUrl "$base/tools/test/latest-fixture.json" 3>$null | Out-Null
$j3 = Get-Content $out3 -Raw | ConvertFrom-Json
Check 'feed down: falls back to live json' ($j3.id -eq 'SVLeErWYejo' -and $j3.source -eq 'live-site') "$($j3.id) $($j3.source)"

# 4. Real YouTube feed, one attempt (it is flaky; report, don't fail)
$out4 = Join-Path $tmp 'real.json'
& $script -Path $out4 -RetryWaits 0 -FallbackUrl "$base/nope.json" 3>$null | Out-Null
if (Test-Path $out4) { Write-Host "INFO  real feed: $(Get-Content $out4 -Raw)" } else { Write-Host 'INFO  real feed: YouTube RSS not answering right now (known flakiness)' }

Remove-Item $tmp -Recurse -Force
Write-Host "Done, $fails failure(s)"
exit $fails
