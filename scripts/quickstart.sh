#!/bin/bash

set -e

echo "🚀 KI-Disposition Quick Start"
echo "=============================="
echo ""

# Check Prerequisites
echo "✓ Checking prerequisites..."
command -v docker >/dev/null 2>&1 || { echo "❌ Docker is required but not installed."; exit 1; }
command -v docker-compose >/dev/null 2>&1 || { echo "❌ Docker Compose is required but not installed."; exit 1; }
echo "✓ Docker and Docker Compose found"
echo ""

# Create .env if not exists
if [ ! -f .env ]; then
  echo "📝 Creating .env from .env.example..."
  cp .env.example .env
  echo "✓ .env created. Update it with your config if needed."
  echo ""
fi

# Build and start services
echo "🐳 Starting Docker services..."
docker-compose build --no-cache
docker-compose up -d

echo ""
echo "⏳ Waiting for services to be ready..."
sleep 10

# Check if services are healthy
echo ""
echo "🔍 Checking service health..."

# Check Backend
if curl -s http://localhost:3000/api/health | grep -q "ok"; then
  echo "✓ Backend is running (http://localhost:3000)"
else
  echo "⚠️  Backend might still be starting..."
fi

# Check Frontend
if curl -s http://localhost:3001 >/dev/null 2>&1; then
  echo "✓ Frontend is running (http://localhost:3001)"
else
  echo "⚠️  Frontend might still be starting..."
fi

# Check Database
if docker-compose exec -T postgres psql -U kidb -d ki_disposition -c "SELECT 1" >/dev/null 2>&1; then
  echo "✓ Database is running"
else
  echo "⚠️  Database might still be starting..."
fi

echo ""
echo "=============================="
echo "✅ Setup complete!"
echo ""
echo "📊 Access the system:"
echo "   • Dispatcher Dashboard: http://localhost:3001"
echo "   • Backend API:          http://localhost:3000/api"
echo "   • API Health:           http://localhost:3000/api/health"
echo ""
echo "🐳 Docker Compose:"
echo "   • View logs:     docker-compose logs -f"
echo "   • Stop services: docker-compose down"
echo "   • Restart:       docker-compose restart"
echo ""
echo "💡 Next steps:"
echo "   1. Open http://localhost:3001 in your browser"
echo "   2. Create test data or upload Otto Dörner CSV"
echo "   3. Click 'Optimiere Routen' to test the system"
echo ""
