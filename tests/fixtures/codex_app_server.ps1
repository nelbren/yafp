# Offline JSON-RPC peer for the native PowerShell client.
$fixture = Get-Content -Raw $env:YAFP_CODEX_TEST_FIXTURE | ConvertFrom-Json -AsHashtable
while ($null -ne ($line = [Console]::ReadLine())) {
    $request = ConvertFrom-Json -InputObject $line -AsHashtable
    Add-Content -Path $env:YAFP_CODEX_TEST_LOG -Value $line
    if ($request.method -eq 'initialized') { continue }
    $result = switch ($request.method) {
        initialize { @{} }
        'account/read' { @{ account = $fixture.account } }
        'account/rateLimits/read' {
            if ($fixture.delay) { Start-Sleep -Milliseconds $fixture.delay }
            $fixture.result
        }
        default { exit 1 }
    }
    [Console]::WriteLine('malformed line')
    [Console]::WriteLine('{"method":"account/updated","params":{}}')
    $response = @{ id = $request.id; result = $result }
    if ($fixture.error -eq $request.method) { $response = @{ id = $request.id; error = @{ message = 'PRIVATE' } } }
    [Console]::WriteLine(($response | ConvertTo-Json -Compress -Depth 10))
}
