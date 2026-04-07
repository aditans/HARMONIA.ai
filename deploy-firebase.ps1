#!/usr/bin/env pwsh

# Harmonia AI - Gemini API Deployment Script
# This script automates the deployment of Gemini API key to Firebase Functions

Write-Host "=================================" -ForegroundColor Green
Write-Host "Harmonia AI - Firebase Deployment" -ForegroundColor Green
Write-Host "=================================" -ForegroundColor Green
Write-Host ""

# Check if in correct directory
if (-not (Test-Path "firebase.json")) {
    Write-Host "Error: firebase.json not found" -ForegroundColor Red
    Write-Host "Please run this script from c:\HARMONIA.ai" -ForegroundColor Red
    exit 1
}

# Step 1: Check Firebase CLI
Write-Host "Step 1: Checking Firebase CLI..." -ForegroundColor Cyan
try {
    firebase --version | Out-Null
    Write-Host "✓ Firebase CLI installed" -ForegroundColor Green
} catch {
    Write-Host "✗ Firebase CLI not found. Install with: npm install -g firebase-tools" -ForegroundColor Red
    exit 1
}

# Step 2: Login
Write-Host ""
Write-Host "Step 2: Firebase Authentication..." -ForegroundColor Cyan
Write-Host "Note: Keep the authentication window open. Press Enter when logged in..."
Read-Host "Press Enter to open login window"
firebase login

if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Firebase login failed" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Firebase authenticated" -ForegroundColor Green

# Step 3: Set project
Write-Host ""
Write-Host "Step 3: Setting Firebase Project..." -ForegroundColor Cyan
firebase use --add

if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Failed to set Firebase project" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Firebase project set" -ForegroundColor Green

# Step 4: Deploy secret
Write-Host ""
Write-Host "Step 4: Setting Gemini API Key Secret..." -ForegroundColor Cyan
Write-Host "When prompted, paste your NEW API key (NOT the exposed one)" -ForegroundColor Yellow
firebase functions:secrets:set GEMINI_API_KEY

if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Failed to set secret" -ForegroundColor Red
    exit 1
}
Write-Host "✓ API key secret deployed" -ForegroundColor Green

# Step 5: Verify secret
Write-Host ""
Write-Host "Step 5: Verifying Secret..." -ForegroundColor Cyan
firebase functions:secrets:list

# Step 6: Install function dependencies
Write-Host ""
Write-Host "Step 6: Installing Function Dependencies..." -ForegroundColor Cyan
if (Test-Path "functions") {
    Push-Location functions
    npm install
    if ($LASTEXITCODE -ne 0) {
        Write-Host "✗ npm install failed" -ForegroundColor Red
        Pop-Location
        exit 1
    }
    Pop-Location
    Write-Host "✓ Dependencies installed" -ForegroundColor Green
}

# Step 7: Deploy functions
Write-Host ""
Write-Host "Step 7: Deploying Cloud Functions..." -ForegroundColor Cyan
firebase deploy --only functions

if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Function deployment failed" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Cloud Functions deployed" -ForegroundColor Green

# Step 8: Get project ID
Write-Host ""
Write-Host "Step 8: Extracting Project ID..." -ForegroundColor Cyan
$projectId = firebase use | ForEach-Object {
    if ($_ -match "Currently using alias '([^']+)'") {
        $matches[1]
    }
}

if ($projectId) {
    Write-Host "✓ Project ID: $projectId" -ForegroundColor Green
    Write-Host ""
    Write-Host "NEXT STEP: Update lib/features/assistant/services/ai_service.dart" -ForegroundColor Yellow
    Write-Host "Replace YOUR_PROJECT_ID with: $projectId" -ForegroundColor Yellow
} else {
    Write-Host "⚠ Could not determine project ID. Check google-services.json" -ForegroundColor Yellow
}

# Summary
Write-Host ""
Write-Host "=================================" -ForegroundColor Green
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "=================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Update AIService URL with your project ID"
Write-Host "2. Run: flutter pub get"
Write-Host "3. Run: flutter run"
Write-Host "4. Test AI Assistant in the app"
Write-Host ""
Write-Host "For help, see: DEPLOYMENT_CHECKLIST.md or GEMINI_API_DEPLOYMENT.md" -ForegroundColor Cyan
