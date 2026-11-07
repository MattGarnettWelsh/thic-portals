#Requires -Version 5.1
<#
.SYNOPSIS
    Packages the Thic-Portals addon into a CurseForge-ready zip.

.DESCRIPTION
    Builds the file list by walking the addon folder and skipping the entries
    in $Excluded, then writes each one into the zip individually. Nothing in
    the working directory is copied, moved or deleted, so the local .git folder
    stays exactly where it is - it is simply never added to the archive.

    Entries are written with an explicit "ThicPortals/..." forward-slash name.
    Both details matter: CurseForge and the WoW client expect a single
    top-level addon folder, and .NET's CreateFromDirectory helper writes
    backslash separators on Windows PowerShell, which is off-spec and trips up
    some extractors.

.PARAMETER Version
    Overrides the version. Defaults to the "## Version:" line in ThicPortals.toc.

.PARAMETER OutDir
    Where to write the zip. Defaults to .\dist.

.PARAMETER Force
    Overwrite an existing zip of the same version.

.EXAMPLE
    .\build.ps1
    Builds dist\ThicPortals-3.5.0.zip from the version in the .toc.

.EXAMPLE
    .\build.ps1 -Version 3.5.1-beta -Force
#>
[CmdletBinding()]
param(
    [string]$Version,
    [string]$OutDir = (Join-Path $PSScriptRoot 'dist'),
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$AddonName  = 'ThicPortals'
$SourceRoot = $PSScriptRoot

# Top-level items kept out of the package. Everything else ships as-is, so
# adding a new Lua file needs no change here.
$Excluded = @(
    '.git'
    '.github'
    '.gitignore'
    '.gitattributes'
    '.vscode'
    'dist'
    'tests'
    'Testaments'
    'build.ps1'
    '# ThicPortals Workflow - README.md'
)

# --- Resolve the version -------------------------------------------------
if (-not $Version) {
    $tocPath = Join-Path $SourceRoot "$AddonName.toc"
    if (-not (Test-Path -LiteralPath $tocPath)) {
        throw "Cannot find $tocPath - run this script from the addon folder."
    }

    $versionLine = Select-String -LiteralPath $tocPath -Pattern '^##\s*Version:\s*(.+?)\s*$' |
        Select-Object -First 1
    if (-not $versionLine) {
        throw "No '## Version:' line found in $tocPath."
    }

    $Version = $versionLine.Matches[0].Groups[1].Value
}

$zipName = "$AddonName-$Version.zip"
$zipPath = Join-Path $OutDir $zipName

if ((Test-Path -LiteralPath $zipPath) -and -not $Force) {
    throw "$zipPath already exists. Bump the version, or re-run with -Force to overwrite it."
}

# --- Collect the shipping files ------------------------------------------
Write-Host "Packaging $AddonName $Version" -ForegroundColor Cyan

# --- Keep the TOC flavours in step ---------------------------------------
# Multi-TOC ships one .toc per client flavour. They must list the same Lua
# files and carry the same version, or a client quietly loads a different
# addon than the one that was tested.
function Get-TocFacts([string]$Path) {
    $lines = Get-Content -LiteralPath $Path
    return [pscustomobject]@{
        Files   = @($lines |
            Where-Object { $_ -notmatch '^\s*#' -and $_.Trim() -ne '' } |
            ForEach-Object { $_.Trim() })
        Version = @($lines | Where-Object { $_ -match '^##\s*Version:' })[0]
    }
}

$tocFiles  = @(Get-ChildItem -LiteralPath $SourceRoot -Filter "$AddonName*.toc" -File | Sort-Object Name)
$baseFacts = Get-TocFacts (Join-Path $SourceRoot "$AddonName.toc")

foreach ($toc in $tocFiles) {
    if ($toc.Name -eq "$AddonName.toc") { continue }

    $facts = Get-TocFacts $toc.FullName

    $fileDiff = Compare-Object $baseFacts.Files $facts.Files
    if ($fileDiff) {
        $detail = ($fileDiff | ForEach-Object { "$($_.SideIndicator) $($_.InputObject)" }) -join '; '
        throw "$($toc.Name) does not list the same files as $AddonName.toc -> $detail"
    }
    if ($facts.Version -ne $baseFacts.Version) {
        throw "$($toc.Name) has '$($facts.Version)' but $AddonName.toc has '$($baseFacts.Version)' - versions must match."
    }
}

Write-Host "  TOC flavours in step: $(($tocFiles | ForEach-Object { $_.Name }) -join ', ')"

$prefixLength = $SourceRoot.TrimEnd('\').Length + 1

# -Force so hidden items (.git) are enumerated and excluded by name rather
# than skipped silently - an exclusion that only works by accident is worse
# than no exclusion at all.
$files = Get-ChildItem -LiteralPath $SourceRoot -Force |
    Where-Object { $Excluded -notcontains $_.Name } |
    ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -Recurse -Force -File } |
    ForEach-Object {
        [pscustomobject]@{
            Path      = $_.FullName
            EntryName = "$AddonName/" + $_.FullName.Substring($prefixLength).Replace('\', '/')
        }
    }

$files = @($files)
if ($files.Count -eq 0) {
    throw "No files matched - nothing to package."
}

$leaked = @($files | Where-Object { $_.EntryName -match '(^|/)\.git/' })
if ($leaked.Count -gt 0) {
    throw "$($leaked.Count) .git entries reached the file list - aborting rather than packaging them."
}

# --- Syntax-check the Lua that is about to ship --------------------------
# WoW runs Lua 5.1, so LuaJIT is the faithful parser; stock lua will do. Only
# interpreters supporting -e are used, so the parse error comes back on stdout.
# Skipped with a notice when neither is installed, so this script still works
# on a machine without one.
function Find-LuaInterpreter {
    foreach ($name in 'luajit', 'lua') {
        $command = Get-Command $name -ErrorAction SilentlyContinue
        if ($command) {
            return $command.Source
        }
    }

    foreach ($candidate in @(
            (Join-Path $env:LOCALAPPDATA 'Programs\LuaJIT\bin\luajit.exe')
            (Join-Path $env:LOCALAPPDATA 'Programs\Lua\bin\lua.exe')
        )) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    return $null
}

$luaExe = Find-LuaInterpreter
if (-not $luaExe) {
    Write-Host "  Lua syntax check SKIPPED - no luajit or lua found" -ForegroundColor Yellow
} else {
    $luaFiles = @($files | Where-Object { $_.Path -like '*.lua' })
    $syntaxErrors = @()

    foreach ($luaFile in $luaFiles) {
        # Forward slashes so the path survives Lua's string literal unescaped.
        # [char]92 and [char]47 keep an escaped backslash out of this file.
        $literal = $luaFile.Path.Replace([char]92, [char]47)

        # No 2>&1: redirecting a native command's stderr in Windows PowerShell
        # wraps each line in an ErrorRecord and corrupts $?.
        $parseError = & $luaExe -e "local chunk, err = loadfile('$literal'); if not chunk then io.write(err); os.exit(1) end"

        if ($LASTEXITCODE -ne 0) {
            $syntaxErrors += "$($luaFile.EntryName): $parseError"
        }
    }

    if ($syntaxErrors.Count -gt 0) {
        throw "Lua syntax errors - refusing to package:`n  $($syntaxErrors -join "`n  ")"
    }

    Write-Host "  $($luaFiles.Count) Lua files parsed clean ($(Split-Path -Leaf $luaExe))"
}

# --- Write the zip -------------------------------------------------------
if (-not (Test-Path -LiteralPath $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
}
if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}

# ZipFile/ZipFileExtensions live in the FileSystem assembly, ZipArchiveMode in
# the base one - Windows PowerShell autoloads neither.
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$archive = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($file in $files) {
        Write-Verbose "  + $($file.EntryName)"
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $archive,
            $file.Path,
            $file.EntryName,
            [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
}
finally {
    $archive.Dispose()
}

# --- Verify what actually landed in the zip ------------------------------
$archive = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
try {
    $entryNames = @($archive.Entries | ForEach-Object { $_.FullName })
}
finally {
    $archive.Dispose()
}

$gitEntries = @($entryNames | Where-Object { $_ -match '(^|/)\.git/' })
if ($gitEntries.Count -gt 0) {
    throw "Package contains $($gitEntries.Count) .git entries - do not upload it."
}

$badRoot = @($entryNames | Where-Object { $_ -notlike "$AddonName/*" })
if ($badRoot.Count -gt 0) {
    throw "These entries are not under '$AddonName/': $($badRoot -join ', ')"
}

$backslashes = @($entryNames | Where-Object { $_ -like '*\*' })
if ($backslashes.Count -gt 0) {
    throw "$($backslashes.Count) entries used backslash separators - extractors will mangle them."
}

$sizeKb = [math]::Round((Get-Item -LiteralPath $zipPath).Length / 1KB, 1)
Write-Host "Built $zipPath" -ForegroundColor Green
Write-Host "  $($entryNames.Count) files, $sizeKb KB, rooted at $AddonName/ , no .git"
