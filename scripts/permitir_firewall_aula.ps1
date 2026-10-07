# Permite que la app del docente reciba a los alumnos a traves del Firewall
# de Windows. Ejecutar UNA vez por equipo docente, en PowerShell como
# administrador:
#
#   powershell -ExecutionPolicy Bypass -File scripts\permitir_firewall_aula.ps1
#
# Abre solo los puertos del aula (UDP 47800 para el descubrimiento y TCP
# 47801-47810 para la conexion) y en todos los perfiles: las redes escolares
# suelen quedar marcadas como "Publicas", y ahi Windows bloquea por defecto.
# Para quitar las reglas:
#
#   powershell -ExecutionPolicy Bypass -File scripts\permitir_firewall_aula.ps1 -Quitar

param([switch]$Quitar)

$ErrorActionPreference = "Stop"
$principal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Este script necesita ejecutarse como administrador." -ForegroundColor Red
    exit 1
}

$reglas = @(
    @{ Nombre = "Transformer Visualizer - Aula (descubrimiento UDP)"; Protocolo = "UDP"; Puertos = "47800" },
    @{ Nombre = "Transformer Visualizer - Aula (conexion TCP)";        Protocolo = "TCP"; Puertos = "47801-47810" }
)

foreach ($regla in $reglas) {
    Get-NetFirewallRule -DisplayName $regla.Nombre -ErrorAction SilentlyContinue |
        Remove-NetFirewallRule
    if (-not $Quitar) {
        New-NetFirewallRule -DisplayName $regla.Nombre -Direction Inbound -Action Allow `
            -Protocol $regla.Protocolo -LocalPort $regla.Puertos -Profile Any | Out-Null
        Write-Host "Regla creada: $($regla.Nombre)" -ForegroundColor Green
    } else {
        Write-Host "Regla eliminada: $($regla.Nombre)"
    }
}
