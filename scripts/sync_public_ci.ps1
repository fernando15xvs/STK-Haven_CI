param(
    [string]$PublicRepo = "fernando15xvs/STK-Haven_CI",
    [string]$SourceBranch = "feat/roadmap-2-complete"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$RootDir = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RootDir

function Require-Command([string]$Name) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Falta el comando '$Name' en PATH."
    }
}

Require-Command git
Require-Command gh

Write-Host "== STK Haven -> Public CI mirror =="
Write-Host "Fuente: $SourceBranch"
Write-Host "Destino publico: $PublicRepo"
Write-Host ""

git fetch origin $SourceBranch
if ($LASTEXITCODE -ne 0) { throw "No se pudo actualizar origin/$SourceBranch." }

$SourceRef = "origin/$SourceBranch"
$SourceSha = (git rev-parse $SourceRef).Trim()
if ($LASTEXITCODE -ne 0) { throw "No se pudo resolver $SourceRef." }
Write-Host "Snapshot fuente: $SourceSha"

$TrackedPaths = @(git ls-tree -r --name-only $SourceRef)
$ForbiddenPathPatterns = @(
    '(^|/)\.env($|\.)',
    '(^|/)key\.properties$',
    '\.(jks|keystore|p12|pem|key)$',
    '(^|/)local\.properties$',
    '(^|/)google-services\.json$',
    '(^|/)GoogleService-Info\.plist$',
    '(^|/)(secrets?|credentials?)(\.|/|$)',
    'backup.*\.(json|zip|db)$'
)

$ForbiddenPaths = @()
foreach ($Path in $TrackedPaths) {
    foreach ($Pattern in $ForbiddenPathPatterns) {
        if ($Path -match $Pattern) {
            $ForbiddenPaths += $Path
            break
        }
    }
}

if ($ForbiddenPaths.Count -gt 0) {
    Write-Host "ERROR: archivos sensibles rastreados:"
    $ForbiddenPaths | Sort-Object -Unique | ForEach-Object { Write-Host "  $_" }
    throw "Se cancela la publicacion."
}

$SecretPatterns = @(
    '-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----',
    '\bghp_[A-Za-z0-9]{20,}\b',
    '\bgithub_pat_[A-Za-z0-9_]{20,}\b',
    '\bsb_secret_[A-Za-z0-9_-]{10,}\b',
    '\bsbp_[A-Za-z0-9]{20,}\b',
    '\bAIza[0-9A-Za-z_-]{30,}\b',
    '\bsk-[A-Za-z0-9_-]{20,}\b',
    '\bAKIA[0-9A-Z]{16}\b'
)

foreach ($Pattern in $SecretPatterns) {
    # Use -e so a pattern beginning with "-" is parsed as a pattern,
    # not as another git-grep command option.
    $SecretHits = @(git grep -n -I -E -e $Pattern $SourceRef -- . 2>$null)
    if ($LASTEXITCODE -notin @(0, 1)) {
        throw "Fallo el escaneo de secretos para patron: $Pattern"
    }
    if ($SecretHits.Count -gt 0) {
        Write-Host "ERROR: posible secreto encontrado:"
        $SecretHits | ForEach-Object { Write-Host $_ }
        throw "Se cancela la publicacion."
    }
}

$JwtPattern = '\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b'
$JwtHits = @(git grep -n -I -E -e $JwtPattern $SourceRef -- . 2>$null)
if ($LASTEXITCODE -notin @(0, 1)) { throw "Fallo el escaneo JWT." }
if ($JwtHits.Count -gt 0) {
    Write-Host "ERROR: JWT literal encontrado. Revisalo antes de publicar:"
    $JwtHits | ForEach-Object { Write-Host $_ }
    throw "Se cancela la publicacion para revision manual."
}

$TempBase = Join-Path ([System.IO.Path]::GetTempPath()) ("stk-haven-public-ci-" + [Guid]::NewGuid().ToString("N"))
$Archive = "$TempBase.zip"
$Snapshot = "$TempBase-snapshot"

try {
    git archive --format=zip --output=$Archive $SourceRef
    if ($LASTEXITCODE -ne 0) { throw "git archive fallo." }

    Expand-Archive -LiteralPath $Archive -DestinationPath $Snapshot

    $WorkflowDir = Join-Path $Snapshot ".github/workflows"
    if (Test-Path $WorkflowDir) {
        Remove-Item $WorkflowDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $WorkflowDir -Force | Out-Null
    Copy-Item (Join-Path $RootDir "ci/public/flutter_ci.yml") (Join-Path $WorkflowDir "flutter_ci.yml") -Force

    $SnapshotNote = @"
# Public CI snapshot

This repository is a history-free CI mirror of the private STK Haven source.

Source commit: $SourceSha
Source branch: $SourceBranch

The private Git history, local signing material, environment files, credentials,
backups and other excluded local files are intentionally not mirrored.
"@
    Set-Content -LiteralPath (Join-Path $Snapshot "PUBLIC_CI_SNAPSHOT.md") -Value $SnapshotNote -Encoding UTF8

    Push-Location $Snapshot
    try {
        git init -b main
        if ($LASTEXITCODE -ne 0) { throw "git init fallo." }

        git config user.name "STK Haven CI Mirror"
        git config user.email "ci-mirror@users.noreply.github.com"
        git add --all
        git commit -m "ci: publish sanitized STK Haven snapshot $SourceSha"
        if ($LASTEXITCODE -ne 0) { throw "No se pudo crear el commit del snapshot." }

        $PublicRepoParts = $PublicRepo.Split('/', 2)
        if ($PublicRepoParts.Count -ne 2) {
            throw "PublicRepo debe tener formato owner/repo."
        }
        $PublicOwner = $PublicRepoParts[0]
        $PublicName = $PublicRepoParts[1]

        # Listing repositories succeeds whether or not the target repo exists,
        # avoiding the expected stderr/NativeCommandError produced by
        # 'gh repo view' on Windows PowerShell when the repo is absent.
        $ExistingRepoNames = @(gh repo list $PublicOwner --limit 1000 --json name --jq '.[].name')
        if ($LASTEXITCODE -ne 0) {
            throw "No se pudo consultar la lista de repositorios de $PublicOwner."
        }

        if ($ExistingRepoNames -notcontains $PublicName) {
            Write-Host "Creando repositorio publico $PublicRepo ..."
            gh repo create $PublicRepo --public --description "History-free public CI mirror for STK Haven" --disable-issues --disable-wiki
            if ($LASTEXITCODE -ne 0) { throw "No se pudo crear $PublicRepo." }
        }
        else {
            Write-Host "Repositorio publico existente: $PublicRepo"
        }

        git remote add origin "https://github.com/$PublicRepo.git"
        git push --force origin main
        if ($LASTEXITCODE -ne 0) { throw "No se pudo publicar el snapshot." }
    }
    finally {
        Pop-Location
    }

    Write-Host ""
    Write-Host "SUCCESS: snapshot publico publicado."
    Write-Host "Repo: https://github.com/$PublicRepo"
    Write-Host "Fuente privada: $SourceSha"
    Write-Host "Git history privado: NO copiado."
}
finally {
    Remove-Item $Archive -Force -ErrorAction SilentlyContinue
    Remove-Item $Snapshot -Recurse -Force -ErrorAction SilentlyContinue
}
