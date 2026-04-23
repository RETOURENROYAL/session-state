# R³|VIB.E — Claude Code CLI → Free LiteLLM Backend
# In PowerShell ausführen BEVOR claude gestartet wird:

$env:ANTHROPIC_BASE_URL = "http://localhost:4000/v1"
$env:ANTHROPIC_API_KEY  = "r3-local"

Write-Host "✓ Claude Code → LiteLLM Gateway :4000 (FREE)" -ForegroundColor Green
Write-Host "  Nutzt: Groq llama-3.3-70b + Ollama Fallback" -ForegroundColor Gray
Write-Host ""
Write-Host "  claude                     # Starten" -ForegroundColor Cyan
Write-Host "  r3-code.bat                # aider (Groq)" -ForegroundColor Cyan
Write-Host "  r3-code.bat local          # aider (Ollama offline)" -ForegroundColor Cyan
