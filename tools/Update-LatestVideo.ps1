<#
.SYNOPSIS
  Writes latest.json (+ a self-hosted thumbnail) for the newest non-Shorts upload on the PetterTech channel.

.DESCRIPTION
  Reads the channel's public RSS feed (no API key). The feed is known to answer 404/500
  for hours at a time, so the script retries, and if the feed is still down it re-uses
  the latest.json that is already live on the site. If nothing works it writes no file
  and the page simply shows the plain YouTube card.

  The thumbnail is downloaded next to latest.json as latest-<id>.jpg, so visitors never
  load anything from Google.
#>
[CmdletBinding()]
param(
    [string]$ChannelId = 'UCQI_069-AC_iU8Tw9nP-a3A',
    [string]$Path = 'latest.json',
    [string]$FeedUrl = "https://www.youtube.com/feeds/videos.xml?channel_id=$ChannelId",
    [string]$FallbackUrl = 'https://pettertech.com/latest.json',
    [string]$ThumbnailBaseUrl = 'https://i.ytimg.com/vi',
    [int[]]$RetryWaits = @(0, 30, 120)
)
$ErrorActionPreference = 'Stop'

# ASCII only and no trailing newline (\z) - same rule as the regex in site.js.
function Test-VideoId([string]$Id) { $Id -cmatch '^[A-Za-z0-9_-]{11}\z' }

function ConvertTo-UtcStamp($Value) {
    try { ([datetimeoffset][string]$Value).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') } catch { $null }
}

function Get-CleanTitle($Value) {
    $t = ([string]$Value) -replace '[\r\n\t]+', ' '
    if ($t.Length -gt 200) { $t = $t.Substring(0, 200) }
    $t.Trim()
}

function Get-LatestFromFeed {
    $ns = @{ a = 'http://www.w3.org/2005/Atom'; yt = 'http://www.youtube.com/xml/schemas/2015' }
    foreach ($wait in $RetryWaits) {
        if ($wait -gt 0) { Write-Host "Feed failed, retrying in $wait s"; Start-Sleep -Seconds $wait }
        try {
            $response = Invoke-WebRequest -Uri $FeedUrl -TimeoutSec 20
            [xml]$xml = $response.Content    # PowerShell's [xml] uses XmlResolver=null (no XXE)
            $entries = Select-Xml -Xml $xml -XPath '//a:entry' -Namespace $ns | ForEach-Object Node
        }
        catch {
            Write-Warning "Feed request failed: $($_.Exception.Message)"
            continue
        }
        foreach ($entry in $entries) {
            try {
                $link = ($entry.link | Where-Object rel -eq 'alternate' | Select-Object -First 1).href
                if ($link -match '/shorts/') { continue }   # keep Shorts off the front page
                $id = [string]$entry.videoId
                if (-not (Test-VideoId $id)) { continue }
                return [ordered]@{
                    id        = $id
                    title     = Get-CleanTitle $entry.title
                    published = ConvertTo-UtcStamp $entry.published
                    source    = 'rss'
                }
            }
            catch { Write-Warning "Skipping a feed entry: $($_.Exception.Message)" }
        }
        Write-Warning 'Feed answered, but contained no regular videos.'
        return $null
    }
    return $null
}

function Get-LatestFromLiveSite {
    try {
        $live = Invoke-RestMethod -Uri $FallbackUrl -TimeoutSec 20
        if (Test-VideoId ([string]$live.id)) {
            Write-Host "Re-using live latest.json ($($live.id))"
            return [ordered]@{
                id        = [string]$live.id
                title     = Get-CleanTitle $live.title
                published = ConvertTo-UtcStamp $live.published
                source    = 'live-site'
            }
        }
    }
    catch { Write-Warning "Live fallback failed: $($_.Exception.Message)" }
    return $null
}

function Save-Thumbnail([string]$Id, [string]$Directory) {
    $target = Join-Path $Directory "latest-$Id.jpg"
    foreach ($name in 'maxresdefault.jpg', 'hqdefault.jpg') {
        $tmp = "$target.part"
        try {
            Invoke-WebRequest -Uri "$ThumbnailBaseUrl/$Id/$name" -TimeoutSec 20 -OutFile $tmp
            $bytes = [IO.File]::ReadAllBytes($tmp)
            # must be a real JPEG of sane size before we publish it
            if ($bytes.Length -gt 1000 -and $bytes.Length -lt 3MB -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xD8) {
                Move-Item -Path $tmp -Destination $target -Force
                return $true
            }
            Write-Warning "Thumbnail $name is not a usable JPEG ($($bytes.Length) bytes)"
        }
        catch { Write-Warning "Thumbnail $name failed: $($_.Exception.Message)" }
        finally { if (Test-Path $tmp) { Remove-Item $tmp -Force } }
    }
    return $false
}

$latest = Get-LatestFromFeed
if (-not $latest) { $latest = Get-LatestFromLiveSite }

if ($latest) {
    $dir = Split-Path -Parent $Path
    if (-not $dir) { $dir = '.' }
    $latest.thumbnail = Save-Thumbnail -Id $latest.id -Directory $dir
    $latest.fetched = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    $latest | ConvertTo-Json | Set-Content -Path $Path -Encoding utf8NoBOM
    Write-Host "Wrote $Path -> $($latest.id): $($latest.title) [$($latest.source), thumbnail: $($latest.thumbnail)]"
}
else {
    Write-Warning 'No latest video available; the page will show the plain YouTube card.'
}
