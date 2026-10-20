# Gathers every SAT-project file on this PC into Desktop\SAT_Project.
# It only COPIES files. Nothing is moved or deleted.
# Run it (in PowerShell):
#   powershell -ExecutionPolicy Bypass -File "$HOME\Downloads\collect_sat_project_windows.ps1"

$ErrorActionPreference = 'SilentlyContinue'
$Home_      = $env:USERPROFILE
$Desktop    = [Environment]::GetFolderPath('Desktop')
$Documents  = [Environment]::GetFolderPath('MyDocuments')
$Downloads  = Join-Path $Home_ 'Downloads'
$Dest       = Join-Path $Desktop 'SAT_Project'
$RecentDays = 3      # downloads from the last N days are pulled in for review
$MaxMB      = 200    # bigger files are listed but not copied

# Filename keywords. "sat" must be its own word, so "saturday" or "satisfy" don't match.
$NameRe    = '(^|[^a-z])(sat|psat|dsat)([^a-z]|$)|sparkl|test[ _-]?bank|bluebook|college[ _-]?board|^build\.py$|initialize_activity|xhr[ _-]?log'
# Text inside files (only checked in Downloads, Desktop, Documents).
$ContentRe = 'Sparkl|initialize_activity|[Tt]est [Bb]ank|College ?Board|Bluebook|SAT (Math|Reading|Writing|[Pp]ractice|[Tt]est|[Qq]uestion|[Pp]roject)'
$TextExt   = @('.py','.js','.md','.txt','.json','.html','.csv','.tsv','.tex','.log')
$SkipDirs  = @('AppData','node_modules','.git','.cache','$Recycle.Bin','Application Data','Local Settings','SAT_Project')

Write-Host "Searching your PC. This can take a few minutes..."
New-Item -ItemType Directory -Force -Path $Dest | Out-Null

# Walk a folder tree, skipping system and app folders
function Get-Files($root) {
  $stack = New-Object System.Collections.Stack
  if (Test-Path $root) { $stack.Push($root) }
  while ($stack.Count -gt 0) {
    $dir = $stack.Pop()
    foreach ($item in (Get-ChildItem -LiteralPath $dir -Force)) {
      if ($item.PSIsContainer) {
        if ($SkipDirs -notcontains $item.Name -and -not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
          $stack.Push($item.FullName)
        }
      } else { $item }
    }
  }
}

$matched = @{}
# 1) Name matches anywhere in your user folder (includes OneDrive)
foreach ($f in (Get-Files $Home_)) {
  if ($f.Name.ToLower() -match $NameRe) { $matched[$f.FullName] = $f }
}
# 2) Content matches in the usual places
foreach ($root in @($Downloads, $Desktop, $Documents) | Select-Object -Unique) {
  foreach ($f in (Get-Files $root)) {
    if ($matched.ContainsKey($f.FullName)) { continue }
    if ($TextExt -contains $f.Extension.ToLower() -and $f.Length -lt 2MB) {
      if (Select-String -LiteralPath $f.FullName -Pattern $ContentRe -CaseSensitive -Quiet) { $matched[$f.FullName] = $f }
    }
  }
}
# 3) Anything downloaded recently that didn't match (you check these by hand)
$cutoff = (Get-Date).AddDays(-$RecentDays)
$review = @(Get-ChildItem -LiteralPath $Downloads -File -Force -Recurse -Depth 1 |
  Where-Object { $_.LastWriteTime -gt $cutoff -and -not $matched.ContainsKey($_.FullName) -and $_.Name -ne 'desktop.ini' })

function Get-Category($ext) {
  switch ($ext.ToLower()) {
    { $_ -in '.md','.txt','.rtf','.log' }                              { return '01_chat_and_notes' }
    { $_ -in '.docx','.doc','.pdf','.pptx','.ppt','.odt' }             { return '02_documents' }
    { $_ -in '.py','.js','.ts','.sh','.ps1','.ipynb','.html','.htm','.css','.tex' } { return '03_code' }
    { $_ -in '.json','.csv','.tsv','.xlsx','.xls','.xml','.yaml','.yml','.har' }   { return '04_data' }
    { $_ -in '.png','.jpg','.jpeg','.gif','.webp','.svg','.heic' }    { return '05_images' }
    { $_ -in '.zip' }                                                  { return '06_archives' }
    default                                                            { return '07_other' }
  }
}

$manifest = New-Object System.Collections.ArrayList
$skipped  = New-Object System.Collections.ArrayList
function Copy-One($f, $sub) {
  if ($f.Length -gt ($MaxMB * 1MB)) { [void]$skipped.Add($f.FullName); return }
  $dir = Join-Path $Dest $sub
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $target = Join-Path $dir $f.Name; $n = 2
  while (Test-Path -LiteralPath $target) {
    $existing = Get-Item -LiteralPath $target
    if ($existing.Length -eq $f.Length -and
        (Get-FileHash -LiteralPath $target).Hash -eq (Get-FileHash -LiteralPath $f.FullName).Hash) { return }  # exact duplicate
    $target = Join-Path $dir ("{0}_{1}{2}" -f $f.BaseName, $n, $f.Extension); $n++
  }
  Copy-Item -LiteralPath $f.FullName -Destination $target
  [void]$manifest.Add([pscustomobject]@{
    File = "$sub/" + (Split-Path $target -Leaf); Modified = $f.LastWriteTime.ToString('yyyy-MM-dd HH:mm')
    KB = [math]::Ceiling($f.Length / 1KB); Original = $f.FullName })
  if ($f.Extension -ieq '.zip') {
    Expand-Archive -LiteralPath $target -DestinationPath ($target.Substring(0, $target.Length - 4) + '_unzipped') -Force
  }
}

foreach ($f in ($matched.Values | Sort-Object FullName)) { Copy-One $f (Get-Category $f.Extension) }
foreach ($f in $review) { Copy-One $f '00_REVIEW_recent_downloads' }

$transcript = Join-Path $Dest 'CHAT_TRANSCRIPT.md'
if (-not (Test-Path $transcript)) {
@'
# Chat transcript from the old account

Paste the ENTIRE old SAT Project chat below this line, then save.

---
'@ | Set-Content -LiteralPath $transcript -Encoding UTF8
}

@'
# Claude: start here

This folder holds an SAT Project that began in another Claude account. That
account ran out of usage, so the work continues here.

## Read in this order
1. `CHAT_TRANSCRIPT.md`: the full old conversation (the source of truth).
2. `README_FILE_INDEX.md`: every file in this folder and where it came from.
3. The files themselves, in the numbered folders.

## Where the work stopped
The last request in the old chat was:
1. Render the test bank docs: run `build.py` (it was at `/home/claude/tb/build.py`)
   and write the output to `out/`. Look for `build.py` in `03_code/`.
2. Retry the Sparkl "anonymous-copy" investigation in a browser tab
   (dispatch `initialize_activity` with the XHR logger). This needs Claude in Chrome
   signed in to this account. The old tab ID (939864817) no longer exists.
3. Upload everything to the claude.ai Project.

## What to do
- Read the transcript and confirm the plan with the user before running anything.
- Rebuild any missing source files from the transcript.
- Files in `00_REVIEW_recent_downloads/` matched no SAT keyword. The user should
  check them before you rely on them.
'@ | Set-Content -LiteralPath (Join-Path $Dest 'CLAUDE_START_HERE.md') -Encoding UTF8

$lines = New-Object System.Collections.ArrayList
[void]$lines.Add('# SAT Project: file index'); [void]$lines.Add('')
[void]$lines.Add("Made $((Get-Date).ToString('yyyy-MM-dd HH:mm')) by collect_sat_project_windows.ps1. All files are copies; the originals were not touched.")
[void]$lines.Add('')
[void]$lines.Add('| Folder | What''s in it |'); [void]$lines.Add('|---|---|')
[void]$lines.Add('| `00_REVIEW_recent_downloads` | Recent downloads that matched no SAT keyword. Check these and delete any that aren''t part of the project. |')
[void]$lines.Add('| `01_chat_and_notes` | Text, Markdown and notes |')
[void]$lines.Add('| `02_documents` | Word, PDF and slides |')
[void]$lines.Add('| `03_code` | Scripts, including build.py |')
[void]$lines.Add('| `04_data` | JSON, CSV, spreadsheets and logs |')
[void]$lines.Add('| `05_images` | Screenshots and pictures |')
[void]$lines.Add('| `06_archives` | Zip files, each with an `_unzipped` folder next to it |')
[void]$lines.Add('| `07_other` | Everything else |')
[void]$lines.Add(''); [void]$lines.Add('## Every file'); [void]$lines.Add('')
[void]$lines.Add('| File | Modified | Size (KB) | Original location |'); [void]$lines.Add('|---|---|---|---|')
foreach ($m in ($manifest | Sort-Object File)) {
  [void]$lines.Add("| ``$($m.File)`` | $($m.Modified) | $($m.KB) | ``$($m.Original)`` |")
}
if ($skipped.Count -gt 0) {
  [void]$lines.Add(''); [void]$lines.Add("## Too big to copy (over $MaxMB MB), left where they are"); [void]$lines.Add('')
  foreach ($s in $skipped) { [void]$lines.Add("- ``$s``") }
}
$lines | Set-Content -LiteralPath (Join-Path $Dest 'README_FILE_INDEX.md') -Encoding UTF8

Write-Host ""
Write-Host "Done. Copied $($manifest.Count) files into: $Dest"
Write-Host "Next: open CHAT_TRANSCRIPT.md in that folder and paste the old chat into it."
Start-Process explorer.exe $Dest
