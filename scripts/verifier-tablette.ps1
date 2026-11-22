<#
  Verification complete de pop_tablet avant deploiement : une seule commande, arret au premier echec.
  Usage (PowerShell, depuis n'importe ou) : scripts\verifier-tablette.ps1
  Etapes : tests Lua, audit Lua, luacheck, luac -p, vitest, build, robot Playwright (Edge/Chrome deja installe).
  Code de sortie 0 si tout passe, 1 au premier echec.
#>
$ErrorActionPreference = 'Stop'
$racine = Split-Path -Parent $PSScriptRoot
$tablette = Join-Path $racine 'resources\[pop]\pop_tablet'
$ui = Join-Path $racine 'ui\pop-os'
$resultats = [System.Collections.Generic.List[object]]::new()

function Trouver([string[]]$noms) {
  foreach ($n in $noms) { $c = Get-Command $n -ErrorAction SilentlyContinue; if ($c) { return $c.Source } }
  throw "Outil introuvable : $($noms -join ' ou ')"
}

function Etape([string]$nom, [string]$dossier, [scriptblock]$action) {
  Write-Host "`n=== $nom ===" -ForegroundColor Cyan
  $debut = Get-Date
  Push-Location -LiteralPath $dossier
  try {
    $global:LASTEXITCODE = 0
    & $action
    $ok = ($LASTEXITCODE -eq 0)
  } catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    $ok = $false
  } finally { Pop-Location }
  $duree = [int]((Get-Date) - $debut).TotalSeconds
  $resultats.Add([pscustomobject]@{ Etape = $nom; Resultat = $(if ($ok) { 'OK' } else { 'ECHEC' }); Secondes = $duree })
  if (-not $ok) {
    Write-Host "`nRESUME" -ForegroundColor Yellow
    $resultats | Format-Table -AutoSize | Out-String | Write-Host
    Write-Host "ECHEC a l'etape : $nom. Rien d'autre n'a ete lance. Ne deployez pas." -ForegroundColor Red
    exit 1
  }
}

$lua = Trouver @('lua', 'lua5.4')
$luac = Trouver @('luac', 'luac5.4')
$luacheck = Trouver @('luacheck')
$pnpm = Trouver @('pnpm')

Etape 'Tests Lua (tests/run.lua)' $tablette { & $lua 'tests/run.lua' }
Etape 'Audit Lua (tests/audit.lua)' $tablette { & $lua 'tests/audit.lua' }
Etape 'luacheck (config du depot)' $racine { & $luacheck 'resources/[pop]/pop_tablet' --config '.luacheckrc' --no-color }
Etape 'luac -p (syntaxe, hors utility_lib)' $tablette {
  $fichiers = Get-ChildItem -LiteralPath $tablette -Recurse -Filter '*.lua' | Where-Object { $_.FullName -notmatch '[\\/](utility_lib|node_modules)[\\/]' }
  foreach ($f in $fichiers) {
    & $luac -p $f.FullName
    if ($LASTEXITCODE -ne 0) { Write-Host "Syntaxe invalide : $($f.FullName)" -ForegroundColor Red; break }
  }
  if ($LASTEXITCODE -eq 0) { Write-Host "$($fichiers.Count) fichiers .lua : syntaxe OK" }
}
Etape 'Types et tests unitaires (pnpm test)' $ui { & $pnpm 'run' 'typecheck'; if ($LASTEXITCODE -eq 0) { & $pnpm 'test' } }
Etape 'Build (pnpm build) et controle du dist' $ui { & $pnpm 'build'; if ($LASTEXITCODE -eq 0) { & $pnpm 'run' 'verify' } }
Etape 'Robot Playwright (scenarios de bout en bout)' $ui { & $pnpm 'exec' 'playwright' 'test' }

Write-Host "`nRESUME" -ForegroundColor Green
$resultats | Format-Table -AutoSize | Out-String | Write-Host
Write-Host 'TOUT EST VERT : la tablette peut etre deployee.' -ForegroundColor Green
exit 0
