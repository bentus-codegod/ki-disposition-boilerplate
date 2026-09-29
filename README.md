# KI-Disposition: Self-Hosted Routing Optimization

Ein kompletes, kostenlos selbstgebautes System für Real-Time Route Optimization in der Kurzstreckenlogistik.

## 🚀 Features

- **Vehicle Routing Problem (VRP) Solver** - Google OR-Tools Integration
- **Real-time Route Replanning** - Bei Ausfällen automatisch neu optimieren
- **Dispatcher Dashboard** - React Web UI mit Live-Karte
- **Fahrer App** - React Native für iOS/Android
- **Geo-Datenbank** - PostgreSQL + PostGIS
- **Multi-Tenant Ready** - Für mehrere Logistik-Partner
- **Opportunity Matching** - Automatische Job-Zuordnung bei Kapazitätsfreiheit

## 📋 Stack

| Komponente | Tool | Lizenz | Kosten |
|-----------|------|--------|--------|
| Routing Engine | Google OR-Tools | Apache 2.0 | €0 |
| Kartendaten | OpenStreetMap | ODbL | €0 |
| Backend | Node.js + Express | MIT | €0 |
| Datenbank | PostgreSQL + PostGIS | Postgres/GPLv2 | €0 |
| Frontend | React | MIT | €0 |
| Mobile | React Native + Expo | MIT | €0 |
| Hosting | Hetzner/Railway | - | €3-50/Monat |

## ⚡ Quick Start

### 1. Voraussetzungen

```bash
# Installiert?
node --version          # v18+
docker --version        # Latest
docker-compose --version # Latest
python --version        # v3.8+
```

### 2. Repository klonen + Setup

```bash
git clone https://github.com/you/ki-disposition.git
cd ki-disposition

# Alle Services starten (Docker)
docker-compose up -d

# Backend-Dependencies installieren
cd backend && npm install && cd ..

# Frontend-Dependencies installieren
cd frontend && npm install && cd ..
```

### 3. Datenbank initialisieren

```bash
docker-compose exec postgres psql -U kidb -d ki_disposition -f /scripts/init-db.sql
```

### 4. Test-API aufrufen

```bash
curl http://localhost:3000/api/health
# Response: {"status": "ok"}
```

### 5. Interfaces öffnen

- **Dispatcher Dashboard:** http://localhost:3000
- **API:** http://localhost:3000/api
- **Swagger Docs:** http://localhost:3000/api/docs

## 📁 Verzeichnis-Struktur

```
ki-disposition/
├── backend/                 # Node.js Express Server
│   ├── src/
│   │   ├── api/            # REST Endpoints
│   │   ├── services/       # Business Logic (VRP, Routing)
│   │   ├── models/         # Database Models
│   │   └── utils/          # Helper Functions
│   ├── package.json
│   ├── server.js
│   └── Dockerfile
├── frontend/               # React Dashboard
│   ├── src/
│   │   ├── components/    # React Components
│   │   ├── pages/         # Page Components
│   │   └── App.js
│   ├── package.json
│   └── Dockerfile
├── mobile/                # React Native App
│   ├── app.json
│   ├── App.js
│   └── package.json
├── database/              # PostgreSQL Scripts
│   ├── init-db.sql       # Schema + Initial Data
│   └── migrations/       # Schema Changes
├── scripts/              # Utility Scripts
│   └── deploy.sh        # Deployment Script
├── docker-compose.yml   # All Services
├── .env.example        # Environment Template
└── docs/               # Documentation
```

## 🏗️ Architektur

```
┌─────────────────────────┐
│ Fahrer App (React Native)
│ GPS + Task Completion   │
└────────────┬────────────┘
             │ WebSocket
┌────────────▼────────────────────────────────────┐
│         Node.js Backend (Express)                │
│  ┌─────────────────────────────────────────┐   │
│  │ VRP Solver (Google OR-Tools)            │   │
│  │ Route Optimization Engine               │   │
│  └─────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────┐   │
│  │ REST API + WebSocket Server             │   │
│  │ /api/routes, /api/tasks, /api/vehicles  │   │
│  └─────────────────────────────────────────┘   │
└──────────┬─────────────────────────┬────────────┘
           │                         │
           │                    ┌────▼──────┐
           │                    │ OSRM Router│
        ┌──▼──────┐            │(Distances)│
        │PostgreSQL+            └───────────┘
        │PostGIS   │
        │(Geo DB)  │
        └──────────┘
           ▲
           │
┌──────────┴───────────────┐
│ React Dashboard          │
│ Dispatcher UI (Web)      │
└──────────────────────────┘
```

## 🚀 Deployment

### Lokal (Development)

```bash
docker-compose up -d
# All services running on localhost
```

### Production (Hetzner)

```bash
# 1. VPS mieten (€7/Monat)
# 2. SSH login
# 3. Docker installieren
# 4. Repository klonen
# 5. docker-compose up -d

# Siehe scripts/deploy.sh für Details
```

## 📊 KPIs & Monitoring

- **Route Efficiency:** % Capacity Utilization
- **Failure Detection:** Ausfallrate pro Fahrer
- **Optimization Impact:** Ersparnis vs. manuell geplant
- **Real-time Updates:** Replanning latency

## 🔐 Sicherheit

- [x] PostgreSQL mit Passwörtern
- [x] HTTPS ready (selbstsigniert lokal)
- [x] API Rate Limiting
- [x] JWT Authentication (optional)
- [x] Environment Secrets

## 📚 Docs

- [Backend Setup](./docs/BACKEND.md)
- [Frontend Setup](./docs/FRONTEND.md)
- [Mobile Setup](./docs/MOBILE.md)
- [Database Schema](./docs/DATABASE.md)
- [OR-Tools Integration](./docs/ORTOOLS.md)
- [Deployment Guide](./docs/DEPLOYMENT.md)

## 🤝 Lizenz

MIT - Alles frei verwendbar.

## 💬 Support

Fragen? Schreib eine Issue oder PR!

---

**Status:** MVP Ready
**Last Updated:** 2026-09-29
**Autor:** Lisa Karsten
