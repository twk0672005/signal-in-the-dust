$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath('C:\Users\tsang\DeepSpaceRover\deep-space-rover-three-20260906')
$stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$backup = Join-Path 'C:\Users\tsang\DeepSpaceRover\backups' ('pre-godot-unification-' + $stamp)
$archive = Join-Path $root 'legacy\aurelia-threejs'
$source = Join-Path $root 'legacy\signal-in-the-dust\godot'
$target = Join-Path $root 'godot'
if (Test-Path -LiteralPath $target) { throw 'Godot target already exists; reconcile before retry.' }
if (Test-Path -LiteralPath $archive) { throw 'AURELIA archive already exists; reconcile before retry.' }
function InsideRoot([string]$path) {
  $resolved = [IO.Path]::GetFullPath($path)
  if (-not $resolved.StartsWith($root + '\', [StringComparison]::OrdinalIgnoreCase)) { throw "Outside root: $resolved" }
}
function Inventory([string]$base) {
  @(Get-ChildItem -LiteralPath $base -File -Recurse -Force | Where-Object { $_.FullName -notmatch '\\(node_modules|\.godot|\.git)\\' } | ForEach-Object {
    [pscustomobject]@{ path=[IO.Path]::GetRelativePath($base,$_.FullName); bytes=$_.Length; sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
  })
}
function CopyVerified([string]$from,[string]$to) {
  $inventory = Inventory $from
  foreach($file in $inventory) {
    $dest = Join-Path $to $file.path
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($dest)) | Out-Null
    Copy-Item -LiteralPath (Join-Path $from $file.path) -Destination $dest
    if ((Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash -ne $file.sha256) { throw "Hash mismatch: $dest" }
  }
  return ,$inventory
}
[IO.Directory]::CreateDirectory($backup) | Out-Null
$records = [Collections.Generic.List[object]]::new()
$folders = @('src','public','art-direction','tools','dist','evidence')
foreach($name in $folders + @('legacy\signal-in-the-dust')) {
  $from=Join-Path $root $name
  if(Test-Path -LiteralPath $from) { $inv=CopyVerified $from (Join-Path $backup $name); $records.Add([pscustomobject]@{source=$from;backup=(Join-Path $backup $name);files=$inv}) }
}
$docs = @(Get-ChildItem -LiteralPath $root -File | Where-Object { $_.Extension -eq '.md' -or $_.Name -in @('package.json','package-lock.json','index.html') })
foreach($file in $docs) { Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $backup $file.Name); if((Get-FileHash $file.FullName).Hash -ne (Get-FileHash (Join-Path $backup $file.Name)).Hash){throw 'Root backup mismatch'} }
$godotInventory=CopyVerified $source $target
[IO.Directory]::CreateDirectory($archive) | Out-Null
foreach($name in $folders) {
  $from=Join-Path $root $name; $to=Join-Path $archive $name
  InsideRoot $from; InsideRoot $to
  if(Test-Path -LiteralPath $from) {
    $before=Inventory $from
    Move-Item -LiteralPath $from -Destination $to
    foreach($file in $before) { if((Get-FileHash -LiteralPath (Join-Path $to $file.path)).Hash -ne $file.sha256){throw "Move mismatch: $name"} }
  }
}
foreach($file in $docs) { Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $archive $file.Name) }
[IO.Directory]::CreateDirectory((Join-Path $root 'evidence\migration')) | Out-Null
$receipt=[ordered]@{timestamp=$stamp;root=$root;backup=$backup;godotSource=$source;godotTarget=$target;godotFiles=$godotInventory;archives=$records;status='HASH_VERIFIED';excludedCaches=@('node_modules','.godot','.git');notes='Original legacy Godot retained. Browser profile temp directories left in place and excluded from release.'}
$receipt | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $root 'evidence\migration\manifest.json') -Encoding utf8
[pscustomobject]@{status='HASH_VERIFIED';backup=$backup;godotFiles=$godotInventory.Count;archivedFolders=$folders.Count} | ConvertTo-Json
