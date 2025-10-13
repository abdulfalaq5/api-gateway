#!/bin/bash

# Quick diagnose untuk server Kong
# Usage: ./quick-server-diagnose.sh

echo "================================================"
echo "🔍 QUICK SERVER DIAGNOSIS"
echo "================================================"
echo ""

# 1. Cek koneksi ke backend SSO
echo "1️⃣  Checking Backend SSO Connection:"
echo "   Target: https://api-gate.motorsights.com"
curl -s -o /dev/null -w "Status: %{http_code} | Time: %{time_total}s\n" https://api-gate.motorsights.com/api/auth/sso/login \
    -X POST -H "Content-Type: application/json" -d '{}' --max-time 10
echo ""

# 2. Cek koneksi ke backend Power BI
echo "2️⃣  Checking Backend Power BI Connection:"
echo "   Target: https://api-report-management.motorsights.com"
curl -s -o /dev/null -w "Status: %{http_code} | Time: %{time_total}s\n" https://api-report-management.motorsights.com/api/categories --max-time 10
echo ""

# 3. Cek melalui Kong Gateway
echo "3️⃣  Checking Through Kong Gateway:"
echo "   Target: https://services.motorsights.com"
echo -n "   SSO Login: "
curl -s -o /dev/null -w "Status: %{http_code} | Time: %{time_total}s\n" https://services.motorsights.com/api/auth/sso/login \
    -X POST -H "Content-Type: application/json" -d '{}' --max-time 10 2>/dev/null || echo "TIMEOUT or ERROR"
echo ""

echo "4️⃣  Diagnosis:"
echo "================================================"
echo "Jika backend direct (1,2) works tapi melalui Kong (3) timeout:"
echo "  → Masalah di Kong configuration atau network"
echo ""
echo "Jika backend direct juga timeout:"
echo "  → Masalah di backend service"
echo ""
echo "Possible issues:"
echo "  - DNS resolution di Kong server"
echo "  - Firewall blocking Kong to backend"
echo "  - Backend service down/slow"
echo "  - Kong timeout settings too low"
echo ""
echo "Check Kong logs:"
echo "  docker logs kong 2>&1 | tail -50"
echo ""

