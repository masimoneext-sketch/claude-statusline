# Claude Code Status Line — Multi-line Dashboard with Icons (PowerShell)
# Persists model info and always shows all lines (even after /clear)

$StateFile = Join-Path $env:TEMP ".claude-statusline-state.json"
$input = $Input | Out-String

try {
    $data = $input | ConvertFrom-Json -ErrorAction Stop
} catch {
    $data = $null
}

# --- Extract fields ---
$model = if ($data.model.display_name) { $data.model.display_name } else { $null }
$modelId = if ($data.model.id) { $data.model.id } else { $null }
$used = if ($null -ne $data.context_window.used_percentage) { $data.context_window.used_percentage } else { $null }
$ctxSize = if ($null -ne $data.context_window.context_window_size) { $data.context_window.context_window_size } else { $null }
$inputTokens = if ($null -ne $data.context_window.total_input_tokens) { $data.context_window.total_input_tokens } else { $null }
$outputTokens = if ($null -ne $data.context_window.total_output_tokens) { $data.context_window.total_output_tokens } else { $null }
$costUsd = if ($null -ne $data.cost.total_cost_usd) { $data.cost.total_cost_usd } else { $null }
$rate5h = if ($null -ne $data.rate_limits.five_hour.used_percentage) { $data.rate_limits.five_hour.used_percentage } else { $null }
$rate5hReset = if ($null -ne $data.rate_limits.five_hour.resets_at) { $data.rate_limits.five_hour.resets_at } else { $null }
$rate7d = if ($null -ne $data.rate_limits.seven_day.used_percentage) { $data.rate_limits.seven_day.used_percentage } else { $null }
$rate7dReset = if ($null -ne $data.rate_limits.seven_day.resets_at) { $data.rate_limits.seven_day.resets_at } else { $null }

# --- Persist model & rate limits (survive /clear) ---
if ($model -and $modelId) {
    @{
        Model = $model
        ModelId = $modelId
        CtxSize = $ctxSize
        Rate5h = $rate5h
        Rate5hReset = $rate5hReset
        Rate7d = $rate7d
        Rate7dReset = $rate7dReset
    } | ConvertTo-Json | Set-Content -Path $StateFile -Encoding UTF8
} elseif (Test-Path $StateFile) {
    try {
        $saved = Get-Content $StateFile -Raw | ConvertFrom-Json
        if (-not $model) { $model = $saved.Model }
        if (-not $modelId) { $modelId = $saved.ModelId }
        if ($null -eq $ctxSize) { $ctxSize = $saved.CtxSize }
        if ($null -eq $rate5h) { $rate5h = $saved.Rate5h }
        if ($null -eq $rate5hReset) { $rate5hReset = $saved.Rate5hReset }
        if ($null -eq $rate7d) { $rate7d = $saved.Rate7d }
        if ($null -eq $rate7dReset) { $rate7dReset = $saved.Rate7dReset }
    } catch {}
}

# --- Defaults ---
if (-not $model) { $model = "Claude" }
if (-not $modelId) { $modelId = "--" }
if ($null -eq $used) { $used = 0 }
if ($null -eq $ctxSize) { $ctxSize = 200000 }
if ($null -eq $inputTokens) { $inputTokens = 0 }
if ($null -eq $outputTokens) { $outputTokens = 0 }
if ($null -eq $costUsd) { $costUsd = 0 }

# --- ANSI Colors ---
$ESC = [char]27
$RST = "$ESC[0m"
$BOLD = "$ESC[1m"
$DIM = "$ESC[2m"
$WHITE = "$ESC[1;97m"
$MAGENTA = "$ESC[1;95m"
$GREEN = "$ESC[1;92m"
$YELLOW = "$ESC[1;93m"
$RED = "$ESC[1;91m"
$CYAN = "$ESC[1;96m"
$BLUE = "$ESC[1;94m"

# --- Helpers ---
function Pick-Color([int]$val) {
    if ($val -ge 80) { return $RED }
    elseif ($val -ge 50) { return $YELLOW }
    else { return $GREEN }
}

function Make-Bar([int]$pct, [int]$width = 20) {
    $filled = [math]::Floor($pct * $width / 100)
    $empty = $width - $filled
    return ("$([char]0x2588)" * $filled) + ("$([char]0x2591)" * $empty)
}

function Format-Tokens([double]$t) {
    if ($t -ge 1000000) { return "{0:F1}M" -f ($t / 1000000) }
    elseif ($t -ge 1000) { return "{0:F1}k" -f ($t / 1000) }
    else { return [string][int]$t }
}

function Time-UntilReset($resetTs) {
    if ($null -eq $resetTs) { return "" }
    $now = [int](Get-Date -UFormat %s)
    $diff = [int]$resetTs - $now
    if ($diff -le 0) { return "adesso" }
    $hours = [math]::Floor($diff / 3600)
    $mins = [math]::Floor(($diff % 3600) / 60)
    if ($hours -gt 0) { return "{0}h {1}m" -f $hours, $mins }
    else { return "{0}m" -f $mins }
}

$UsdToEur = 0.91

# === LINE 1: MODEL ===
Write-Output "$([char]0x1F916) ${MAGENTA}${BOLD}${model}${RST} ${DIM}(${modelId})${RST}"

# === LINE 2: CONTEXT WINDOW ===
$usedInt = [math]::Round($used)
$ctxColor = Pick-Color $usedInt
$bar = Make-Bar $usedInt 20
$ctxLabel = " / $(Format-Tokens $ctxSize)"
Write-Output "$([char]0x1F4CA) ${WHITE}Contesto${RST}  ${ctxColor}${bar} ${usedInt}%${RST}${DIM}${ctxLabel}${RST}"

# === LINE 3: TOKENS ===
$inFmt = Format-Tokens $inputTokens
$outFmt = Format-Tokens $outputTokens
$total = [double]$inputTokens + [double]$outputTokens
$totalFmt = Format-Tokens $total
Write-Output "$([char]0x1F524) ${WHITE}Token${RST}     ${CYAN}$([char]0x2193) ${inFmt} input${RST}  ${BLUE}$([char]0x2191) ${outFmt} output${RST}  ${DIM}$([char]0x03A3) ${totalFmt}${RST}"

# === LINE 4: COST ===
$costEur = [math]::Round($costUsd * $UsdToEur, 4)
$usdFmt = "{0:F4}" -f [double]$costUsd
$eurFmt = "{0:F4}" -f $costEur
if ([double]$costUsd -ge 1.0) { $costColor = $RED }
elseif ([double]$costUsd -ge 0.1) { $costColor = $YELLOW }
else { $costColor = $GREEN }
Write-Output "$([char]0x1F4B6) ${WHITE}Costo${RST}     ${costColor}$ ${usdFmt} USD${RST}  $([char]0x2192)  ${costColor}$([char]0x20AC) ${eurFmt} EUR${RST}"

# === LINE 5: RATE 5H ===
if ($null -ne $rate5h) {
    $r5Int = [math]::Round($rate5h)
    $r5Color = Pick-Color $r5Int
    $r5Bar = Make-Bar $r5Int 15
    $r5Reset = ""
    if ($rate5hReset -and $rate5hReset -ne "null") {
        $r5Reset = "  $([char]0x23F3) reset $(Time-UntilReset $rate5hReset)"
    }
    Write-Output "$([char]0x26A1) ${WHITE}Rate 5h${RST}   ${r5Color}${r5Bar} ${r5Int}%${RST}${DIM}${r5Reset}${RST}"
} else {
    Write-Output "$([char]0x26A1) ${WHITE}Rate 5h${RST}   ${DIM}$("$([char]0x2591)" * 15) --%  in attesa...${RST}"
}

# === LINE 6: RATE 7D ===
if ($null -ne $rate7d) {
    $r7Int = [math]::Round($rate7d)
    $r7Color = Pick-Color $r7Int
    $r7Bar = Make-Bar $r7Int 15
    $r7Reset = ""
    if ($rate7dReset -and $rate7dReset -ne "null") {
        $r7Reset = "  $([char]0x23F3) reset $(Time-UntilReset $rate7dReset)"
    }
    Write-Output "$([char]0x1F4C5) ${WHITE}Rate 7d${RST}   ${r7Color}${r7Bar} ${r7Int}%${RST}${DIM}${r7Reset}${RST}"
} else {
    Write-Output "$([char]0x1F4C5) ${WHITE}Rate 7d${RST}   ${DIM}$("$([char]0x2591)" * 15) --%  in attesa...${RST}"
}
