param(
    [string]$InputPath = (Join-Path $PSScriptRoot 'fixtures.json'),
    [string]$OutputPath = (Join-Path $PSScriptRoot 'checks-result.json')
)

$ErrorActionPreference = 'Stop'
$taskData = Get-Content -LiteralPath $InputPath -Raw | ConvertFrom-Json
if ($taskData.synthetic -ne $true) {
    throw 'Only explicitly synthetic rehearsal data is accepted.'
}

function Require-Condition {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-CashSummary {
    param([object[]]$Events)
    [decimal]$balance = 0
    [decimal]$minimumBalance = 0
    [decimal]$totalOutflow = 0
    [decimal]$totalReceipts = 0
    foreach ($event in $Events) {
        Require-Condition ($event.outflow -ge 0 -and $event.receipt -ge 0) 'Cash events must use nonnegative inputs.'
        $balance -= [decimal]$event.outflow
        $totalOutflow += [decimal]$event.outflow
        $minimumBalance = [Math]::Min($minimumBalance, $balance)
        $balance += [decimal]$event.receipt
        $totalReceipts += [decimal]$event.receipt
    }
    return [pscustomobject]@{
        total_outflow = $totalOutflow
        total_receipts = $totalReceipts
        maximum_funding_required = -$minimumBalance
        ending_cash_balance = $balance
    }
}

function Get-ProjectSummary {
    param([object]$CaseData)
    [decimal]$hours = ($CaseData.hours | Measure-Object -Property hours -Sum).Sum
    [decimal]$baseCost = $hours * $CaseData.hourly_cost + $CaseData.cash_cost + $CaseData.allocated_cost
    [decimal]$adverseCost = $baseCost + $CaseData.additional_hours * $CaseData.hourly_cost + $CaseData.additional_cash
    $baselineCash = Get-CashSummary $CaseData.baseline_cash_events
    $adverseCash = Get-CashSummary $CaseData.adverse_cash_events
    Require-Condition ($baselineCash.total_outflow -eq $CaseData.cash_cost) 'Baseline cash schedule does not reconcile with cash cost.'
    Require-Condition ($adverseCash.total_outflow -eq ($CaseData.cash_cost + $CaseData.additional_cash)) 'Adverse cash schedule does not reconcile with cash cost.'
    Require-Condition ($baselineCash.total_receipts -eq $CaseData.candidate_revenue) 'Baseline payment schedule does not reconcile with candidate revenue.'
    Require-Condition ($adverseCash.total_receipts -eq $CaseData.candidate_revenue) 'Adverse payment schedule does not reconcile with candidate revenue.'
    return [pscustomobject]@{
        baseline_hours = $hours
        adverse_hours = $hours + $CaseData.additional_hours
        baseline_cost = $baseCost
        adverse_cost = $adverseCost
        candidate_revenue = $CaseData.candidate_revenue
        baseline_profit = $CaseData.candidate_revenue - $baseCost
        adverse_profit = $CaseData.candidate_revenue - $adverseCost
        baseline_margin_percent = [Math]::Round(100 * ($CaseData.candidate_revenue - $baseCost) / $CaseData.candidate_revenue, 4)
        adverse_margin_percent = [Math]::Round(100 * ($CaseData.candidate_revenue - $adverseCost) / $CaseData.candidate_revenue, 4)
        hours_capacity = $CaseData.hours_capacity
        cash_capacity = $CaseData.cash_capacity
        baseline_cash = $baselineCash
        adverse_cash = $adverseCash
    }
}

$caseA = Get-ProjectSummary $taskData.case_a
$caseC = Get-ProjectSummary $taskData.case_c
$caseBData = $taskData.case_b

Require-Condition ($caseBData.diagnostic_hours -le $caseBData.diagnostic_hours_cap) 'Diagnostic plan exceeds its declared cap.'
Require-Condition (@($caseBData.records | Group-Object id | Where-Object Count -gt 1).Count -eq 0) 'Sample record IDs must be unique.'

$rows = @(
    foreach ($record in $caseBData.records) {
        $rawCode = [string]$record.asset_code
        $normalizedCode = $rawCode.Trim().ToUpperInvariant()
        $mappingCandidates = @($caseBData.mappings | Where-Object { $_.raw -ceq $normalizedCode })
        $parsedDate = [datetime]::MinValue
        $dateIsValid = [datetime]::TryParseExact(
            [string]$record.date,
            'yyyy-MM-dd',
            [System.Globalization.CultureInfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::None,
            [ref]$parsedDate
        )
        $resolvedAsset = $null
        if ([string]::IsNullOrWhiteSpace($rawCode)) {
            $status = 'missing_code'
        } elseif (-not $dateIsValid) {
            $status = 'invalid_date'
        } elseif ($mappingCandidates.Count -eq 0) {
            $status = 'unknown_code'
        } elseif ($mappingCandidates.Count -gt 1) {
            $status = 'ambiguous_code'
        } else {
            $resolvedAsset = $mappingCandidates[0].asset
            if ($rawCode -ceq $resolvedAsset) { $status = 'ready' }
            else { $status = 'normalized' }
        }
        [pscustomobject]@{
            id = $record.id
            status = $status
            resolved_asset = $resolvedAsset
        }
    }
)

$counts = [ordered]@{}
foreach ($statusName in @('ready', 'normalized', 'missing_code', 'unknown_code', 'ambiguous_code', 'invalid_date')) {
    $counts[$statusName] = @($rows | Where-Object { $_.status -eq $statusName }).Count
}
$processable = $counts.ready + $counts.normalized
$reviewRequired = $rows.Count - $processable
Require-Condition ((($counts.Values | Measure-Object -Sum).Sum) -eq $rows.Count) 'Sample classifications do not reconcile with total rows.'
Require-Condition (@($rows | Where-Object { $_.status -notin @('ready', 'normalized') -and $null -ne $_.resolved_asset }).Count -eq 0) 'Unresolved rows must not receive an invented asset assignment.'
Require-Condition ($caseBData.independently_labeled_records -eq 0) 'This fixture has no independent correctness labels; revise the metric if the input changes.'

$caseB = [pscustomobject]@{
    diagnostic_baseline_cost = $caseBData.diagnostic_hours * $caseBData.hourly_cost + $caseBData.cash_cost
    diagnostic_cap_cost = $caseBData.diagnostic_hours_cap * $caseBData.hourly_cost + $caseBData.cash_cost
    diagnostic_baseline_profit = $caseBData.candidate_revenue - ($caseBData.diagnostic_hours * $caseBData.hourly_cost + $caseBData.cash_cost)
    diagnostic_cap_profit = $caseBData.candidate_revenue - ($caseBData.diagnostic_hours_cap * $caseBData.hourly_cost + $caseBData.cash_cost)
    records_total = $rows.Count
    classification_counts = $counts
    processable = $processable
    review_required = $reviewRequired
    processable_coverage_percent = [Math]::Round(100 * $processable / $rows.Count, 4)
    independently_labeled_records = $caseBData.independently_labeled_records
    correctness_percent = $null
    rows = $rows
}

$taskResult = [ordered]@{
    synthetic = $true
    scope = 'Arithmetic, cash schedule reconciliation, and synthetic sample classification only; not skill behavior or customer software testing.'
    case_a = $caseA
    case_b = $caseB
    case_c = $caseC
    reconciliation = 'completed'
}
$taskResult | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $OutputPath -Encoding utf8
$taskResult | ConvertTo-Json -Depth 12
