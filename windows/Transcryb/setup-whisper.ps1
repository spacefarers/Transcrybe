# Whisper.cpp Setup Script
# This script downloads the whisper-cli.exe executable from the official repository

$whisperVersion = "1.5.4"  # Update this to the latest version
$downloadUrl = "https://github.com/ggerganov/whisper.cpp/releases/download/v$whisperVersion/whisper-bin-x64.zip"
$outputDir = "whisper.cpp"
$zipFile = "whisper-bin.zip"

Write-Host "==================================" -ForegroundColor Cyan
Write-Host "Whisper.cpp Setup for Transcryb" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""

# Create whisper.cpp directory if it doesn't exist
if (-not (Test-Path $outputDir)) {
    Write-Host "Creating whisper.cpp directory..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

# Check if whisper-cli.exe already exists
if (Test-Path "$outputDir\whisper-cli.exe") {
    Write-Host "? whisper-cli.exe already exists!" -ForegroundColor Green
    Write-Host ""
    $overwrite = Read-Host "Do you want to download and overwrite it? (y/n)"
    if ($overwrite -ne "y") {
        Write-Host "Setup cancelled." -ForegroundColor Yellow
        exit 0
    }
}

Write-Host ""
Write-Host "Downloading whisper.cpp v$whisperVersion..." -ForegroundColor Yellow
Write-Host "URL: $downloadUrl" -ForegroundColor Gray

try {
    # Download the zip file
    Invoke-WebRequest -Uri $downloadUrl -OutFile $zipFile -UseBasicParsing
    Write-Host "? Download complete!" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "Extracting files..." -ForegroundColor Yellow
    
    # Extract the zip file to a temporary location first
    $tempExtractDir = "temp_whisper_extract"
    if (Test-Path $tempExtractDir) {
        Remove-Item $tempExtractDir -Recurse -Force
    }
    Expand-Archive -Path $zipFile -DestinationPath $tempExtractDir -Force
    
    # Find all DLL and EXE files (we need all of them)
    $exeFiles = Get-ChildItem -Path $tempExtractDir -Filter "*.exe" -Recurse
    $dllFiles = Get-ChildItem -Path $tempExtractDir -Filter "*.dll" -Recurse
    
    $mainExe = $null
    foreach ($exe in $exeFiles) {
        if ($exe.Name -eq "main.exe" -or $exe.Name -eq "whisper-cli.exe" -or $exe.Name -eq "whisper.exe") {
            $mainExe = $exe
     break
        }
    }
    
    if ($mainExe) {
  # Copy/rename the main executable to whisper-cli.exe
        $targetExePath = Join-Path $outputDir "whisper-cli.exe"
    Copy-Item -Path $mainExe.FullName -Destination $targetExePath -Force
        Write-Host "? Copied whisper-cli.exe" -ForegroundColor Green
        
        # Copy all DLL files to the whisper.cpp directory
        Write-Host ""
        Write-Host "Copying required DLL files..." -ForegroundColor Yellow
        $dllCount = 0
        foreach ($dll in $dllFiles) {
   $targetDllPath = Join-Path $outputDir $dll.Name
         Copy-Item -Path $dll.FullName -Destination $targetDllPath -Force
       Write-Host "  ? Copied $($dll.Name)" -ForegroundColor Gray
            $dllCount++
        }
        Write-Host "? Copied $dllCount DLL file(s)" -ForegroundColor Green
        
 } else {
        Write-Host "? Could not find whisper executable in the archive!" -ForegroundColor Red
        Write-Host "Please manually extract and rename the executable to whisper-cli.exe" -ForegroundColor Yellow
    }

    # Clean up temp extraction directory
    if (Test-Path $tempExtractDir) {
        Remove-Item $tempExtractDir -Recurse -Force
    }
    
    # Remove the zip file
    Remove-Item $zipFile -Force
    
    Write-Host ""
    Write-Host "==================================" -ForegroundColor Cyan
    Write-Host "? Setup Complete!" -ForegroundColor Green
    Write-Host "==================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Files installed:" -ForegroundColor White
    Write-Host "  ?? $outputDir\whisper-cli.exe" -ForegroundColor Gray
    $installedFiles = Get-ChildItem -Path $outputDir -Filter "*.dll"
    foreach ($file in $installedFiles) {
     Write-Host "  ?? $outputDir\$($file.Name)" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor White
    Write-Host "  1. Rebuild your solution in Visual Studio" -ForegroundColor Gray
    Write-Host "  2. Run the application" -ForegroundColor Gray
    Write-Host "  3. Download a model from the settings window" -ForegroundColor Gray
    Write-Host ""
    
} catch {
    Write-Host ""
    Write-Host "? Error during setup: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Manual Setup Instructions:" -ForegroundColor Yellow
    Write-Host "1. Visit: https://github.com/ggerganov/whisper.cpp/releases" -ForegroundColor Gray
    Write-Host "2. Download: whisper-bin-x64.zip (or latest Windows release)" -ForegroundColor Gray
    Write-Host "3. Extract the zip file" -ForegroundColor Gray
    Write-Host "4. Find main.exe (or whisper-cli.exe) AND all .dll files" -ForegroundColor Gray
    Write-Host "5. Copy ALL files to: $outputDir\" -ForegroundColor Gray
  Write-Host "6. Rename the exe to: whisper-cli.exe" -ForegroundColor Gray
    Write-Host ""
}

Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
