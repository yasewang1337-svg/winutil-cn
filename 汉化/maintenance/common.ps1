# Shared validation and atomic writes for translation maintenance; no source files are changed here.
function Resolve-WinUtilTranslationFileSystemPath {
    param([Parameter(Mandatory)][string]$Path)
    $provider = $null
    $drive = $null
    # PowerShell's location can differ from Environment.CurrentDirectory after Set-Location.
    # Resolve once through the active provider, then use this absolute path for every I/O operation.
    $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path, [ref]$provider, [ref]$drive)
    if ($null -eq $provider -or $provider.Name -ne 'FileSystem') { throw "只接受文件系统路径：$Path" }
    return $resolved
}

function Invoke-WinUtilTranslationGit {
    param([Parameter(Mandatory)][string[]]$Arguments)
    $git = Get-Command git -CommandType Application -ErrorAction Stop | Select-Object -First 1
    $quoted = foreach ($argument in $Arguments) {
        # ProcessStartInfo.Arguments uses Windows argv quoting, not PowerShell or shell evaluation.
        $escaped = [regex]::Replace($argument, '(\\*)"', '$1$1\"')
        $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
        '"' + $escaped + '"'
    }
    $process = [Diagnostics.Process]::new()
    try {
        $process.StartInfo.FileName = $git.Source
        $process.StartInfo.Arguments = $quoted -join ' '
        $process.StartInfo.UseShellExecute = $false
        $process.StartInfo.CreateNoWindow = $true
        $process.StartInfo.RedirectStandardOutput = $true
        $process.StartInfo.RedirectStandardError = $true
        $process.StartInfo.StandardOutputEncoding = [Text.UTF8Encoding]::new($false, $true)
        $process.StartInfo.StandardErrorEncoding = [Text.UTF8Encoding]::new($false, $true)
        $null = $process.Start()
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        $process.WaitForExit()
        $output = $stdout.GetAwaiter().GetResult()
        $errorOutput = $stderr.GetAwaiter().GetResult()
        if ($process.ExitCode -ne 0) { throw "Git 读取失败（$($process.ExitCode)）：$errorOutput" }
        return $output
    } finally { $process.Dispose() }
}

function Read-WinUtilTranslationJson {
    param([Parameter(Mandatory)][string]$Path)
    $Path = Resolve-WinUtilTranslationFileSystemPath -Path $Path
    $raw = [IO.File]::ReadAllText($Path, [Text.UTF8Encoding]::new($false, $true))
    if ([string]::IsNullOrWhiteSpace($raw)) { throw "JSON 文件为空：$Path" }
    $value = ConvertFrom-Json -InputObject $raw -ErrorAction Stop
    # ConvertFrom-Json can silently discard duplicate object keys. Detect them before accepting a mapping.
    $stack = [Collections.Generic.Stack[object]]::new()
    for ($i = 0; $i -lt $raw.Length; $i++) {
        $character = $raw[$i]
        if ($character -eq '{') {
            $stack.Push([pscustomobject]@{ Type = 'Object'; Keys = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase) })
        } elseif ($character -eq '[') {
            $stack.Push([pscustomobject]@{ Type = 'Array'; Keys = $null })
        } elseif ($character -eq '}' -or $character -eq ']') {
            $null = $stack.Pop()
        } elseif ($character -eq '"') {
            $start = $i
            $i++
            while ($i -lt $raw.Length) {
                if ($raw[$i] -eq '\') { $i += 2; continue }
                if ($raw[$i] -eq '"') { break }
                $i++
            }
            $next = $i + 1
            while ($next -lt $raw.Length -and [char]::IsWhiteSpace($raw[$next])) { $next++ }
            if ($next -lt $raw.Length -and $raw[$next] -eq ':' -and $stack.Count -gt 0 -and $stack.Peek().Type -eq 'Object') {
                $key = ConvertFrom-Json -InputObject $raw.Substring($start, $i - $start + 1)
                if (-not $stack.Peek().Keys.Add([string]$key)) { throw "JSON 含重复字段 '$key'：$Path" }
            }
        }
    }
    if ($raw.TrimStart().StartsWith('[')) { return ,@($value) }
    return $value
}

function Write-WinUtilTranslationJson {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Json, [scriptblock]$Validate)
    $target = Resolve-WinUtilTranslationFileSystemPath -Path $Path
    if (-not [IO.Directory]::Exists([IO.Path]::GetDirectoryName($target))) { throw "输出目录不存在：$target" }
    $temporary = "$target.$([guid]::NewGuid().ToString('N')).tmp"
    try {
        [IO.File]::WriteAllText($temporary, $Json + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
        $parsed = Read-WinUtilTranslationJson -Path $temporary
        if ($Validate) { & $Validate $parsed }
        if ([IO.File]::Exists($target)) { [IO.File]::Replace($temporary, $target, [NullString]::Value) }
        else { [IO.File]::Move($temporary, $target) }
    } finally {
        if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) }
    }
}

function Resolve-WinUtilTranslationFunctionPath {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$RepositoryRoot)
    $RepositoryRoot = Resolve-WinUtilTranslationFileSystemPath -Path $RepositoryRoot
    $portable = $Path.Replace('\', '/')
    if ([IO.Path]::IsPathRooted($Path) -or $portable -notmatch '^functions/.+\.ps1$' -or
        @($portable.Split('/') | Where-Object { $_ -in @('.', '..', '') }).Count) {
        throw "翻译路径必须是 functions/ 下的仓库相对 .ps1 路径：$Path"
    }
    $scope = [IO.Path]::GetFullPath((Join-Path $RepositoryRoot 'functions')) + [IO.Path]::DirectorySeparatorChar
    $resolved = [IO.Path]::GetFullPath((Join-Path $RepositoryRoot $portable))
    if (-not $resolved.StartsWith($scope, [StringComparison]::OrdinalIgnoreCase) -or -not [IO.File]::Exists($resolved)) {
        throw "翻译对应的函数文件不存在或越出 functions/：$Path"
    }
    return $portable
}

function Merge-WinUtilFunctionTranslations {
    param([object[]]$Existing, [object[]]$Incoming, [Parameter(Mandatory)][string]$RepositoryRoot)
    $result = [Collections.Generic.List[object]]::new()
    $index = [Collections.Generic.Dictionary[string,int]]::new([StringComparer]::Ordinal)
    foreach ($group in @(@{ Items = $Existing; Incoming = $false }, @{ Items = $Incoming; Incoming = $true })) {
        $seen = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
        foreach ($entry in $group.Items) {
            if ($null -eq $entry -or $entry.file -isnot [string] -or $entry.en -isnot [string] -or $entry.zh -isnot [string] -or
                [string]::IsNullOrWhiteSpace($entry.en) -or [string]::IsNullOrWhiteSpace($entry.zh) -or $entry.kind -ne 'runtime') {
                throw '运行时翻译条目必须包含有效的 file、en、zh 字符串和 kind=runtime。'
            }
            $file = Resolve-WinUtilTranslationFunctionPath -Path $entry.file -RepositoryRoot $RepositoryRoot
            $key = $file.ToLowerInvariant() + [char]0 + $entry.en
            if ($seen.ContainsKey($key)) {
                if ($seen[$key] -cne $entry.zh) { throw "同一文件/英文存在冲突翻译：$file / $($entry.en)" }
                continue # Existing tables can contain repeated occurrences of the same literal.
            }
            $seen[$key] = $entry.zh
            $normalized = [pscustomobject][ordered]@{ file = $file; en = $entry.en; zh = $entry.zh; kind = 'runtime' }
            if ($index.ContainsKey($key)) { $result[$index[$key]] = $normalized }
            else { $index[$key] = $result.Count; $result.Add($normalized) }
        }
    }
    return ,@($result.ToArray())
}
