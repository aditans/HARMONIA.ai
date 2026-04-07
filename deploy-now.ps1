#!/usr/bin/env pwsh
# Harmonia AI - Gemini API Deployment Script
# Execute this to complete the deployment

Write-Host "========================================" -ForegroundColor Green
Write-Host "Harmonia AI - Deploy Gemini API Key" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# Step 1: Verify project is set
Write-Host "Step 1: Verifying Firebase Project..." -ForegroundColor Cyan
firebase use

Write-Host ""
Write-Host "Step 2: Deploy API Key Secret" -ForegroundColor Cyan
Write-Host "When prompted, paste your NEW Gemini API key" -ForegroundColor Yellow
Write-Host "(NOT the exposed key: AIzaSyCl0ZE7eLPbRaKFhddBQA_IkcB1JAxmhrY)" -ForegroundColor Yellow
Write-Host ""

firebase functions:secrets:set GEMINI_API_KEY

Write-Host ""
Write-Host "Step 3: Verify Secret Deployment" -ForegroundColor Cyan
firebase functions:secrets:list

Write-Host ""
Write-Host "Step 4: Install Function Dependencies" -ForegroundColor Cyan
cd functions
npm install
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Dependencies installed" -ForegroundColor Green
} else {
    Write-Host "✗ npm install failed" -ForegroundColor Red
    exit 1
}
cd ..

Write-Host ""
Write-Host "Step 5: Deploy Cloud Functions" -ForegroundColor Cyan
firebase deploy --only functions

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Cloud Functions deployed successfully" -ForegroundColor Green
} else {
    Write-Host "✗ Function deployment failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "NEXT STEP:" -ForegroundColor Yellow
Write-Host "Update your Flutter code with the project ID" -ForegroundColor Yellow
Write-Host ""
Write-Host "Edit: lib/features/assistant/services/ai_service.dart" -ForegroundColor Cyan
Write-Host ""
Write-Host "Find this line:" -ForegroundColor Cyan
Write-Host "  static const String _functionsUrl =" -ForegroundColor Gray
Write-Host "      'https://us-central1-YOUR_PROJECT_ID.cloudfunctions.net/getAIResponse';" -ForegroundColor Gray
Write-Host ""
Write-Host "Replace with:" -ForegroundColor Cyan
Write-Host "  static const String _functionsUrl =" -ForegroundColor Gray
Write-Host "      'https://us-central1-cashtrack-98bd9.cloudfunctions.net/getAIResponse';" -ForegroundColor Gray
Write-Host ""
Write-Host "Then rebuild:" -ForegroundColor Cyan
Write-Host "  flutter clean && flutter pub get && flutter run" -ForegroundColor Gray
Write-Host ""
Write-Host "Your Harmonia AI AI Assistant will now work! 🚀" -ForegroundColor Green
