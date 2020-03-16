[CmdletBinding()]
param()

Trace-VstsEnteringInvocation $MyInvocation
Import-VstsLocStrings "$PSScriptRoot\task.json"

$sourcePath = Get-VstsInput -Name "Source"
$UIDestinationPath = Get-VstsInput -Name "Destination"
$temp = Get-VstsInput -Name "Temp"
$rootPath = $sourcePath.Remove(0, $sourcePath.LastIndexOf('\') + 1)

try {

    $tempPath = New-Item -ItemType Directory  -Force -Path $temp

    if (Test-Path $tempPath) {
   
        Remove-Item -Recurse -Force -Path $tempPath\*
    }

    $getAllFiles = Get-ChildItem -Path $sourcePath -File -Recurse
 
    foreach ($file in $getAllFiles) {                     

        $childPath = $file.DirectoryName.Substring($file.DirectoryName.IndexOf($rootPath) + $rootPath.Length) 
        $searchPath = Join-Path -Path $UIDestinationPath -ChildPath $childPath
        if (!(Test-Path $searchPath)) {
            write-host $searchPath 
            New-Item -ItemType Directory -Force -Path $searchPath
        }          
        $destinationFile = Get-ChildItem -Path $searchPath -Filter $file.Name
    
        if ([System.IO.File]::Exists($destinationFile.FullName)) {
            $hashes =
            foreach ($Filepath in $file, $destinationFile) {
                $MD5 = [Security.Cryptography.HashAlgorithm]::Create( "MD5" )
                $fileInf = $Filepath.FullName
                $stream = ([IO.StreamReader]"$fileInf").BaseStream
                -join ($MD5.ComputeHash($stream) |
                    ForEach-Object { "{0:x2}" -f $_ })
                $stream.Close()
            }
            if ($hashes.Count -gt 0) {                               
                if ($hashes[0] -eq $hashes[1]) {
                    Write-Host "File is the same, no copying" $file.FullName
                }
              
                else {                                 
                    $changeFilestxt = $file.Name + "<br/>"   
                    $changeFilestxt | Out-File $tempPath\changefiles.txt -Append                        
                    Write-Host "File is different, copying" $file.FullName 
                    $realFile = $file.DirectoryName.Substring($file.DirectoryName.IndexOf($rootPath, 1))
                    $realPath = Join-Path -Path $tempPath -ChildPath $realFile
                    New-Item -ItemType Directory -Force -Path $realPath
                    Copy-Item -Path $file.FullName -Destination $realPath
                }
            }
        }
       
        else {
            $newFilestxt = $file.Name + "<br/>"
            $newFilestxt | Out-File $tempPath\newfiles.txt -Append
            Write-Host "File does not exist, copying"  $file.FullName            
            $realFile = $file.DirectoryName.Substring($file.DirectoryName.IndexOf($rootPath, 1))
            $realPath = Join-Path -Path $tempPath -ChildPath $realFile
            New-Item -ItemType Directory -Force -Path $realPath
            Copy-Item -Path $file.FullName -Destination $realPath
        }
    }   

    if (Test-Path $tempPath\newfiles.txt) {
   
        Remove-Item $tempPath\newfiles.txt
    }

    if (Test-Path $tempPath\changefiles.txt) {
   
        Remove-Item $tempPath\changefiles.txt
    }

}
catch [Exception] {    
    Write-Error ($_.Exception.Message)
}
finally {
    Trace-VstsLeavingInvocation $MyInvocation
}