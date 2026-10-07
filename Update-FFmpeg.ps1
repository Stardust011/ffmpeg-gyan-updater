[CmdletBinding()]
param(
    [ValidateSet('Auto', 'Essentials', 'Full')]
    [string]$BuildType = 'Auto'
)

$ErrorActionPreference = 'Stop'

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message"
}

function Write-Ok {
    param([string]$Message)
    Write-Host "[ OK ] $Message"
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message"
}

function Write-Err {
    param([string]$Message)
    Write-Host "[ERR ] $Message" -ForegroundColor Red
}

function Get-ScriptDirectory {
    if ($PSScriptRoot) {
        return $PSScriptRoot
    }

    return (Split-Path -Parent $MyInvocation.MyCommand.Definition)
}

function Get-CanonicalPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    return [System.IO.Path]::GetFullPath($Path)
}

function Get-UniquePaths {
    param([string[]]$Paths)

    $seen = @{}
    $result = New-Object System.Collections.Generic.List[string]

    foreach ($path in $Paths) {
        if ([string]::IsNullOrWhiteSpace($path)) {
            continue
        }

        $key = $path.ToLowerInvariant()
        if (-not $seen.ContainsKey($key)) {
            $seen[$key] = $true
            [void]$result.Add($path)
        }
    }

    return $result.ToArray()
}

function Get-FFmpegInfo {
    param([Parameter(Mandatory = $true)][string]$FFmpegPath)

    if (-not (Test-Path -LiteralPath $FFmpegPath -PathType Leaf)) {
        return $null
    }

    $lines = & $FFmpegPath -version 2>$null
    if (-not $lines -or $lines.Count -eq 0) {
        return $null
    }

    $firstLine = "$($lines[0])"
    $allText = ($lines -join "`n")
    $version = $null
    $coreVersion = $null

    if ($firstLine -match '^ffmpeg\s+version\s+([^\s]+)') {
        $version = $matches[1]
    }

    if ($version -and ($version -match '^(.*?)-(?:full|essentials)_build(?:-.+)?$')) {
        $coreVersion = $matches[1]
    } else {
        $coreVersion = $version
    }

    $detectedBuild = $null
    if ($allText -match 'full_build') {
        $detectedBuild = 'Full'
    } elseif ($allText -match 'essentials_build') {
        $detectedBuild = 'Essentials'
    }

    [PSCustomObject]@{
        VersionToken = $version
        CoreVersion  = $coreVersion
        BuildType    = $detectedBuild
    }
}

function Get-FFmpegRoot {
    param([Parameter(Mandatory = $true)][string]$FFmpegPath)

    $exeDirectory = Split-Path -Parent $FFmpegPath
    if ((Split-Path -Leaf $exeDirectory).ToLowerInvariant() -eq 'bin') {
        return (Split-Path -Parent $exeDirectory)
    }

    return $exeDirectory
}

function Find-InstalledFFmpeg {
    param([Parameter(Mandatory = $true)][string]$ScriptDirectory)

    $candidatePaths = New-Object System.Collections.Generic.List[string]

    foreach ($direct in @(
        (Join-Path $ScriptDirectory 'bin\ffmpeg.exe'),
        (Join-Path $ScriptDirectory 'ffmpeg.exe')
    )) {
        if (Test-Path -LiteralPath $direct -PathType Leaf) {
            [void]$candidatePaths.Add((Get-CanonicalPath -Path $direct))
        }
    }

    $recursive = Get-ChildItem -LiteralPath $ScriptDirectory -Filter 'ffmpeg.exe' -File -Recurse -ErrorAction SilentlyContinue
    foreach ($item in $recursive) {
        $fullPath = (Get-CanonicalPath -Path $item.FullName)
        if ($fullPath -match '(?i)\\\.ffmpeg-update\\') {
            continue
        }
        if ($fullPath -match '(?i)\\windowsapps\\') {
            continue
        }
        [void]$candidatePaths.Add($fullPath)
    }

    if ($env:Path) {
        $pathEntries = $env:Path -split ';'
        foreach ($entry in $pathEntries) {
            if ([string]::IsNullOrWhiteSpace($entry)) {
                continue
            }

            $expanded = [Environment]::ExpandEnvironmentVariables($entry.Trim())
            if (-not (Test-Path -LiteralPath $expanded -PathType Container)) {
                continue
            }

            $ffmpegInPath = Join-Path $expanded 'ffmpeg.exe'
            if (Test-Path -LiteralPath $ffmpegInPath -PathType Leaf) {
                $fullPath = (Get-CanonicalPath -Path $ffmpegInPath)
                if ($fullPath -match '(?i)\\windowsapps\\') {
                    continue
                }
                [void]$candidatePaths.Add($fullPath)
            }
        }
    }

    $cmd = Get-Command ffmpeg.exe -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) {
        $cmdPath = (Get-CanonicalPath -Path $cmd.Source)
        if (($cmdPath -notmatch '(?i)\\windowsapps\\') -and (Test-Path -LiteralPath $cmdPath -PathType Leaf)) {
            [void]$candidatePaths.Add($cmdPath)
        }
    }

    $ordered = @(Get-UniquePaths -Paths ($candidatePaths.ToArray()) |
        Sort-Object @{ Expression = { $_.Length } }, @{ Expression = { $_ } })

    if ($ordered.Count -gt 0) {
        return $ordered[0]
    }

    return $null
}

function Find-7Zip {
    $candidates = New-Object System.Collections.Generic.List[string]

    foreach ($base in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:LOCALAPPDATA)) {
        if ([string]::IsNullOrWhiteSpace($base)) {
            continue
        }

        foreach ($relative in @(
            '7-Zip\7z.exe',
            '7-Zip\7zz.exe',
            'Programs\7-Zip\7z.exe',
            'Programs\7-Zip\7zz.exe'
        )) {
            $path = Join-Path $base $relative
            if (Test-Path -LiteralPath $path -PathType Leaf) {
                [void]$candidates.Add((Get-CanonicalPath -Path $path))
            }
        }
    }

    foreach ($commandName in @('7z.exe', '7zz.exe')) {
        $cmd = Get-Command $commandName -ErrorAction SilentlyContinue
        if ($cmd -and $cmd.Source) {
            [void]$candidates.Add((Get-CanonicalPath -Path $cmd.Source))
        }
    }

    $unique = @(Get-UniquePaths -Paths ($candidates.ToArray()))
    if ($unique.Count -gt 0) {
        return $unique[0]
    }

    return $null
}

function Invoke-TextRequest {
    param([Parameter(Mandatory = $true)][string]$Uri)

    $response = Invoke-WebRequest -Uri $Uri -UseBasicParsing
    return $response.Content.Trim()
}

function Get-BuildMetadata {
    param([Parameter(Mandatory = $true)][ValidateSet('Essentials', 'Full')][string]$TargetBuild)

    $baseUrl = 'https://www.gyan.dev/ffmpeg/builds'
    $buildKey = if ($TargetBuild -eq 'Full') { 'full' } else { 'essentials' }
    $archiveName = "ffmpeg-git-$buildKey.7z"

    $version = Invoke-TextRequest -Uri "$baseUrl/git-version"
    if ([string]::IsNullOrWhiteSpace($version)) {
        throw 'Could not read latest version from Gyan.dev.'
    }

    $shaLine = Invoke-TextRequest -Uri "$baseUrl/$archiveName.sha256"
    if ($shaLine -notmatch '([A-Fa-f0-9]{64})') {
        throw "Could not parse SHA-256 from $archiveName.sha256"
    }

    [PSCustomObject]@{
        TargetBuild = $TargetBuild
        Version     = $version
        ArchiveName = $archiveName
        ArchiveUrl  = "$baseUrl/$archiveName"
        ExpectedSha = $matches[1].ToLowerInvariant()
    }
}

function Get-FileSha256 {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }

    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Test-ArchiveHash {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$ExpectedSha
    )

    $actualSha = Get-FileSha256 -Path $Path
    if (-not $actualSha) {
        return $false
    }

    Write-Info "SHA-256 check for: $Path"
    Write-Info "Expected: $ExpectedSha"
    Write-Info "Actual:   $actualSha"

    return ($actualSha -ieq $ExpectedSha)
}

function Download-Archive {
    param(
        [Parameter(Mandatory = $true)]$Metadata,
        [Parameter(Mandatory = $true)][string]$DownloadDirectory
    )

    $archivePath = Join-Path $DownloadDirectory $Metadata.ArchiveName
    $partPath = "$archivePath.part"

    if (Test-Path -LiteralPath $archivePath -PathType Leaf) {
        if (Test-ArchiveHash -Path $archivePath -ExpectedSha $Metadata.ExpectedSha) {
            Write-Ok 'Existing archive is valid. Skipping download.'
            return $archivePath
        }

        Write-Warn 'Existing archive SHA-256 mismatch. Removing the invalid archive.'
        Remove-Item -LiteralPath $archivePath -Force
    }

    if (Test-Path -LiteralPath $partPath -PathType Leaf) {
        if (Test-ArchiveHash -Path $partPath -ExpectedSha $Metadata.ExpectedSha) {
            Write-Ok 'Existing .part file is already complete. Restoring archive file.'
            if (Test-Path -LiteralPath $archivePath -PathType Leaf) {
                Remove-Item -LiteralPath $archivePath -Force
            }
            Rename-Item -LiteralPath $partPath -NewName (Split-Path -Leaf $archivePath) -Force
            return $archivePath
        }

        Write-Info 'Resuming download from existing .part file.'
    }

    $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
    if (-not $curl -or -not $curl.Source) {
        throw 'curl.exe not found. Install curl or use a Windows version that includes curl.exe.'
    }

    Write-Info "Downloading archive: $($Metadata.ArchiveUrl)"
    & $curl.Source @(
        '--fail',
        '--location',
        '--retry', '5',
        '--retry-delay', '3',
        '--connect-timeout', '30',
        '-C', '-',
        '--output', $partPath,
        $Metadata.ArchiveUrl
    )

    if ($LASTEXITCODE -ne 0) {
        throw "curl download failed with exit code $LASTEXITCODE. The .part file was kept."
    }

    if (-not (Test-Path -LiteralPath $partPath -PathType Leaf)) {
        throw 'Download finished but .part file was not found.'
    }

    if (Test-Path -LiteralPath $archivePath -PathType Leaf) {
        Remove-Item -LiteralPath $archivePath -Force
    }

    Rename-Item -LiteralPath $partPath -NewName (Split-Path -Leaf $archivePath) -Force

    if (-not (Test-ArchiveHash -Path $archivePath -ExpectedSha $Metadata.ExpectedSha)) {
        throw 'Downloaded archive failed SHA-256 validation. Installation aborted.'
    }

    return $archivePath
}

function Expand-ArchiveWith7Zip {
    param(
        [Parameter(Mandatory = $true)][string]$ArchivePath,
        [Parameter(Mandatory = $true)][string]$WorkingDirectory,
        [Parameter(Mandatory = $true)][string]$SevenZipPath
    )

    $extractDirectory = Join-Path $WorkingDirectory 'extract'
    if (Test-Path -LiteralPath $extractDirectory) {
        Remove-Item -LiteralPath $extractDirectory -Recurse -Force
    }
    [void](New-Item -ItemType Directory -Path $extractDirectory -Force)

    Write-Info "Extracting archive with 7-Zip: $SevenZipPath"
    & $SevenZipPath @('x', '-y', "-o$extractDirectory", $ArchivePath)

    if ($LASTEXITCODE -ne 0) {
        throw "7-Zip extraction failed with exit code $LASTEXITCODE"
    }

    return $extractDirectory
}

function Find-ExtractedRoot {
    param([Parameter(Mandatory = $true)][string]$ExtractDirectory)

    $bins = Get-ChildItem -LiteralPath $ExtractDirectory -Filter 'ffmpeg.exe' -File -Recurse -ErrorAction Stop |
        Where-Object { (Split-Path -Leaf (Split-Path -Parent $_.FullName)).ToLowerInvariant() -eq 'bin' }

    $candidateRoots = New-Object System.Collections.Generic.List[string]

    foreach ($ffmpegExe in $bins) {
        $binDirectory = Split-Path -Parent $ffmpegExe.FullName
        $root = Split-Path -Parent $binDirectory
        $ffprobe = Join-Path $binDirectory 'ffprobe.exe'
        $ffplay = Join-Path $binDirectory 'ffplay.exe'

        if ((Test-Path -LiteralPath $ffprobe -PathType Leaf) -and (Test-Path -LiteralPath $ffplay -PathType Leaf)) {
            [void]$candidateRoots.Add((Get-CanonicalPath -Path $root))
        }
    }

    $orderedRoots = @(Get-UniquePaths -Paths ($candidateRoots.ToArray()) |
        Sort-Object @{ Expression = { $_.Length } }, @{ Expression = { $_ } })

    if ($orderedRoots.Count -eq 0) {
        throw 'Malformed archive: required FFmpeg binaries were not found after extraction.'
    }

    return $orderedRoots[0]
}

function Install-FFmpegFiles {
    param(
        [Parameter(Mandatory = $true)][string]$SourceRoot,
        [Parameter(Mandatory = $true)][string]$TargetRoot
    )

    $sourceBin = Join-Path $SourceRoot 'bin'
    $targetBin = Join-Path $TargetRoot 'bin'

    foreach ($required in @('ffmpeg.exe', 'ffprobe.exe', 'ffplay.exe')) {
        if (-not (Test-Path -LiteralPath (Join-Path $sourceBin $required) -PathType Leaf)) {
            throw "Malformed archive: missing $required in extracted bin directory."
        }
    }

    [void](New-Item -ItemType Directory -Path $targetBin -Force)

    Write-Info 'Installing FFmpeg binaries...'
    Copy-Item -Path (Join-Path $sourceBin '*') -Destination $targetBin -Recurse -Force -ErrorAction Stop

    foreach ($item in @('doc', 'presets', 'LICENSE', 'README.txt')) {
        $sourcePath = Join-Path $SourceRoot $item
        if (-not (Test-Path -LiteralPath $sourcePath)) {
            continue
        }

        $destinationPath = Join-Path $TargetRoot $item

        if (Test-Path -LiteralPath $sourcePath -PathType Container) {
            [void](New-Item -ItemType Directory -Path $destinationPath -Force)
            Copy-Item -Path (Join-Path $sourcePath '*') -Destination $destinationPath -Recurse -Force -ErrorAction Stop
        } else {
            Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Force -ErrorAction Stop
        }
    }
}

function Confirm-InstalledVersion {
    param(
        [Parameter(Mandatory = $true)][string]$TargetRoot,
        [Parameter(Mandatory = $true)]$Metadata
    )

    $ffmpegExe = Join-Path $TargetRoot 'bin\ffmpeg.exe'
    if (-not (Test-Path -LiteralPath $ffmpegExe -PathType Leaf)) {
        throw 'Installation verification failed: bin\ffmpeg.exe not found.'
    }

    $info = Get-FFmpegInfo -FFmpegPath $ffmpegExe
    if (-not $info -or [string]::IsNullOrWhiteSpace($info.CoreVersion)) {
        throw 'Installation verification failed: could not read ffmpeg version.'
    }

    if ($info.CoreVersion -ne $Metadata.Version) {
        throw "Installation verification failed: expected version $($Metadata.Version), found $($info.CoreVersion)."
    }

    if ($info.BuildType -ne $Metadata.TargetBuild) {
        throw "Installation verification failed: expected build $($Metadata.TargetBuild), found $($info.BuildType)."
    }

    Write-Ok 'Installation verification passed.'
    Write-Info "Build:    $($info.BuildType)"
    Write-Info "Version:  $($info.CoreVersion)"
    Write-Info "Location: $TargetRoot"
}

function Invoke-Main {
    Write-Host '============================================'
    Write-Host ' FFmpeg Git Auto Updater'
    Write-Host ' Gyan.dev'
    Write-Host '============================================'
    Write-Host ''

    $scriptDirectory = Get-CanonicalPath -Path (Get-ScriptDirectory)
    $sevenZip = Find-7Zip

    if (-not $sevenZip) {
        throw '7-Zip (7z.exe or 7zz.exe) was not found. Please install 7-Zip and retry.'
    }

    Write-Ok "Using 7-Zip: $sevenZip"

    $installedFFmpeg = Find-InstalledFFmpeg -ScriptDirectory $scriptDirectory
    $installRoot = $scriptDirectory
    $installedInfo = $null

    if ($installedFFmpeg) {
        $installRoot = Get-CanonicalPath -Path (Get-FFmpegRoot -FFmpegPath $installedFFmpeg)
        $installedInfo = Get-FFmpegInfo -FFmpegPath $installedFFmpeg

        Write-Info "Found FFmpeg: $installedFFmpeg"
        Write-Info "Detected FFmpeg root: $installRoot"

        if ($installedInfo -and $installedInfo.CoreVersion) {
            Write-Info "Installed version: $($installedInfo.CoreVersion)"
        }
        if ($installedInfo -and $installedInfo.BuildType) {
            Write-Info "Installed build type: $($installedInfo.BuildType)"
        }
    } else {
        Write-Warn 'No existing FFmpeg installation found. Script directory will be used as install root.'
        Write-Info "Install root: $installRoot"
    }

    $targetBuild = $null
    if ($BuildType -eq 'Auto') {
        if ($installedInfo -and $installedInfo.BuildType) {
            $targetBuild = $installedInfo.BuildType
            Write-Ok "Build type selection: Auto -> $targetBuild"
        } else {
            $targetBuild = 'Full'
            Write-Warn 'Build type selection: Auto -> defaulting to Full.'
        }
    } else {
        $targetBuild = $BuildType
        Write-Ok "Build type selection: Forced -> $targetBuild"
    }

    Write-Info "Checking Gyan.dev for latest $targetBuild Git build..."
    $metadata = Get-BuildMetadata -TargetBuild $targetBuild

    Write-Ok "Latest $targetBuild version: $($metadata.Version)"
    Write-Info "Expected SHA-256: $($metadata.ExpectedSha)"

    if ($installedInfo -and $installedInfo.CoreVersion -and $installedInfo.BuildType) {
        if (($installedInfo.CoreVersion -eq $metadata.Version) -and ($installedInfo.BuildType -eq $targetBuild)) {
            Write-Ok 'FFmpeg is already up to date.'
            return
        }
    }

    $workingDirectory = Join-Path $installRoot '.ffmpeg-update'
    [void](New-Item -ItemType Directory -Path $workingDirectory -Force)

    $archivePath = Download-Archive -Metadata $metadata -DownloadDirectory $installRoot
    Write-Ok "Archive ready: $archivePath"

    $extractDirectory = Expand-ArchiveWith7Zip -ArchivePath $archivePath -WorkingDirectory $workingDirectory -SevenZipPath $sevenZip
    $sourceRoot = Find-ExtractedRoot -ExtractDirectory $extractDirectory

    Write-Info "Extracted source root: $sourceRoot"

    Install-FFmpegFiles -SourceRoot $sourceRoot -TargetRoot $installRoot
    Confirm-InstalledVersion -TargetRoot $installRoot -Metadata $metadata

    if (Test-Path -LiteralPath $archivePath -PathType Leaf) {
        Remove-Item -LiteralPath $archivePath -Force
    }

    $partPath = "$archivePath.part"
    if (Test-Path -LiteralPath $partPath -PathType Leaf) {
        Remove-Item -LiteralPath $partPath -Force
    }

    if (Test-Path -LiteralPath $workingDirectory) {
        Remove-Item -LiteralPath $workingDirectory -Recurse -Force
    }

    Write-Ok 'Update completed successfully.'
}

try {
    Invoke-Main
    exit 0
} catch {
    Write-Err $_.Exception.Message
    Write-Err 'Update failed. Close programs using FFmpeg and retry.'
    exit 1
}
