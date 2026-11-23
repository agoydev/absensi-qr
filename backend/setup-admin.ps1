$ErrorActionPreference = 'Stop'
$password = Read-Host 'Masukkan password baru untuk akun admin (minimal 8 karakter)' -AsSecureString

if ($password.Length -lt 8) {
  $password.Dispose()
  throw 'Password harus minimal 8 karakter.'
}

$passwordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
Push-Location $PSScriptRoot
try {
  $env:ADMIN_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPointer)
  npm run setup-admin
  if ($LASTEXITCODE -ne 0) {
    throw 'Gagal menyiapkan akun admin. Periksa pesan error di atas.'
  }
} finally {
  Remove-Item Env:ADMIN_PASSWORD -ErrorAction SilentlyContinue
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer)
  $password.Dispose()
  Pop-Location
}
