#!/usr/bin/env pwsh
param(
    [ValidateSet("start", "stop", "restart", "logs", "status")]
    [string]$Command = "start",
    [switch]$Follow
)

$ErrorActionPreference = "Stop"

function Assert-Docker {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        throw "docker CLI not found. Install Docker Desktop and ensure 'docker' is on PATH."
    }
}

function Get-ComposeArgs {
    param([string]$BridgeRoot)
    $envFile = Join-Path $BridgeRoot ".env"
    $args = @("-f", (Join-Path $BridgeRoot "docker-compose.yml"))
    if (Test-Path $envFile) {
        $args = @("--env-file", $envFile) + $args
    } else {
        Write-Warning "No .env file found at $envFile. Copy .env.example and update RTSP_URL before first run."
    }
    return $args
}

Assert-Docker

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptRoot "..")
$BridgeRoot = Resolve-Path (Join-Path $RepoRoot "docker/hls-bridge")
$OutputDir = Join-Path $BridgeRoot "output"

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

$composeArgs = Get-ComposeArgs -BridgeRoot $BridgeRoot
$project = "--project-name", "hlsbridge"

switch ($Command) {
    "start" {
        docker compose @project @composeArgs up -d
        docker compose @project @composeArgs ps
    }
    "stop" {
        docker compose @project @composeArgs down
    }
    "restart" {
        docker compose @project @composeArgs down
        docker compose @project @composeArgs up -d
        docker compose @project @composeArgs ps
    }
    "logs" {
        $logArgs = @("logs")
        if ($Follow) { $logArgs += "-f" }
        docker compose @project @composeArgs @logArgs
    }
    "status" {
        docker compose @project @composeArgs ps
    }
}
