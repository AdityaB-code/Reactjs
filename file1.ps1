# ===============================================
# ✅ PowerShell: batch_upload_parallel.ps1
# ===============================================
# 1) Find all images in E:\new
# 2) Process them in batches of 20
# 3) Zip each batch
# 4) Start upload of zip in background (parallel)
# 5) Producer continues with next batch
# ===============================================

$ErrorActionPreference = "Stop"

# === Config ===
$sourceFolder = "E:\new"
$uploadUrl = "http://192.168.231.21:5000/upload_zip"

# === Find all images ===
$imageFiles = Get-ChildItem -Path $sourceFolder -Recurse -Include *.jpg, *.jpeg, *.png, *.bmp, *.gif, *.webp, *.tiff -File

# === Break into batches of 20 ===
$batchSize = 20
$counter = 0

while ($counter -lt $imageFiles.Count) {
    $batch = $imageFiles[$counter..([Math]::Min($counter + $batchSize - 1, $imageFiles.Count - 1))]
    $counter += $batchSize

    # Create unique zip name in temp
    $zipName = "batch_$counter.zip"
    $zipPath = "$env:TEMP\$zipName"

    # Remove old zip if exists
    if (Test-Path $zipPath) {
        Remove-Item $zipPath -Force
    }

    # Create zip
    Add-Type -AssemblyName 'System.IO.Compression.FileSystem'
    $zipFile = [System.IO.Compression.ZipFile]::Open($zipPath, 'Create')

    foreach ($file in $batch) {
        $relativePath = $file.FullName.Substring($sourceFolder.Length).TrimStart('\')
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zipFile, $file.FullName, $relativePath)
    }

    $zipFile.Dispose()
    Write-Host "✅ Created: $zipPath"

    # === Upload zip in background ===
    Start-Job -ScriptBlock {
        param($zipPath, $uploadUrl)

        try {
            Write-Host "🚀 Uploading $zipPath ..."
            & curl.exe -X POST -F $("file=@`"$zipPath`"") $uploadUrl
            Write-Host "✅ Upload done: $zipPath"
        } catch {
            Write-Host "❌ Upload failed: $_"
        } finally {
            if (Test-Path $zipPath) {
                Remove-Item $zipPath -Force
                Write-Host "🧹 Deleted: $zipPath"
            }
        }

    } -ArgumentList $zipPath, $uploadUrl
}

# === Wait for all upload jobs to finish ===
Get-Job | Wait-Job | Receive-Job
Write-Host "✅ All done!"
