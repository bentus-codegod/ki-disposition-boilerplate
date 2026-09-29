.PHONY: help setup build up down logs clean test deploy

help:
	@echo "KI-Disposition - Make Commands"
	@echo "==============================="
	@echo ""
	@echo "Setup & Development:"
	@echo "  make setup         - Setup development environment"
	@echo "  make build         - Build Docker images"
	@echo "  make up            - Start all services"
	@echo "  make down          - Stop all services"
	@echo "  make restart       - Restart all services"
	@echo ""
	@echo "Utilities:"
	@echo "  make logs          - View Docker logs (streaming)"
	@echo "  make backend-logs  - View backend logs only"
	@echo "  make db-logs       - View database logs only"
	@echo "  make db-shell      - Connect to PostgreSQL shell"
	@echo "  make clean         - Remove volumes and containers"
	@echo "  make test          - Run tests"
	@echo ""
	@echo "Deployment:"
	@echo "  make deploy-prod   - Deploy to production"
	@echo "  make deploy-hetzner - Deploy to Hetzner VPS"
	@echo ""

setup:
	@echo "🔧 Setting up development environment..."
	@bash scripts/quickstart.sh

build:
	@echo "🔨 Building Docker images..."
	docker-compose build --no-cache

up:
	@echo "🚀 Starting services..."
	docker-compose up -d
	@echo "✅ Services started!"
	@echo "Dashboard: http://localhost:3001"
	@echo "API: http://localhost:3000"

down:
	@echo "🛑 Stopping services..."
	docker-compose down

restart:
	@echo "🔄 Restarting services..."
	docker-compose restart

logs:
	@echo "📊 Streaming logs (Ctrl+C to exit)..."
	docker-compose logs -f

backend-logs:
	docker-compose logs -f backend

db-logs:
	docker-compose logs -f postgres

db-shell:
	docker-compose exec postgres psql -U kidb -d ki_disposition

db-backup:
	@echo "💾 Backing up database..."
	docker-compose exec postgres pg_dump -U kidb ki_disposition > backup_$(shell date +%Y%m%d_%H%M%S).sql
	@echo "✓ Backup complete"

clean:
	@echo "🧹 Cleaning up..."
	docker-compose down -v
	@echo "✓ Clean complete"

test:
	@echo "🧪 Running tests..."
	docker-compose exec backend npm test
	docker-compose exec frontend npm test

shell-backend:
	docker-compose exec backend sh

shell-frontend:
	docker-compose exec frontend sh

# Production deployments

deploy-prod:
	@echo "🚀 Deploying to production..."
	@echo "TODO: Implement production deployment"
	@echo "Steps:"
	@echo "  1. Verify .env.production"
	@echo "  2. docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d"
	@echo "  3. Run database migrations"

deploy-hetzner:
	@echo "🚀 Deploying to Hetzner VPS..."
	@bash scripts/deploy-hetzner.sh

# Development helpers

lint:
	@echo "🔍 Linting code..."
	docker-compose exec backend npm run lint
	docker-compose exec frontend npm run lint

format:
	@echo "🎨 Formatting code..."
	docker-compose exec backend npm run format
	docker-compose exec frontend npm run format

migrate-db:
	@echo "📦 Running database migrations..."
	docker-compose exec backend npm run migrate

seed-db:
	@echo "🌱 Seeding database..."
	docker-compose exec backend npm run seed

health-check:
	@echo "🏥 Health Check"
	@echo ""
	@echo "Backend:"
	@curl -s http://localhost:3000/api/health | jq . || echo "❌ Backend not responding"
	@echo ""
	@echo "Frontend:"
	@curl -s http://localhost:3001 > /dev/null && echo "✓ Frontend is running" || echo "❌ Frontend not responding"
	@echo ""
	@echo "Database:"
	@docker-compose exec -T postgres psql -U kidb -d ki_disposition -c "SELECT 'Database OK';" 2>/dev/null || echo "❌ Database not responding"

# Statistics

stats:
	@echo "📈 Project Statistics"
	@echo ""
	@echo "Lines of code (excluding node_modules):"
	@find . -type f \( -name "*.js" -o -name "*.jsx" -o -name "*.ts" -o -name "*.tsx" \) -not -path "*/node_modules/*" -exec wc -l {} + | tail -1
	@echo ""
	@echo "File count:"
	@echo "  Backend files:   $$(find backend -type f -not -path "*/node_modules/*" | wc -l)"
	@echo "  Frontend files:  $$(find frontend -type f -not -path "*/node_modules/*" | wc -l)"
	@echo "  Mobile files:    $$(find mobile -type f -not -path "*/node_modules/*" | wc -l)"

.DEFAULT_GOAL := help
