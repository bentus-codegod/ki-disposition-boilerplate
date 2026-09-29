# KI-Disposition Deployment Guide

## 🌍 Produktions-Deployment Optionen

### Option A: Hetzner Cloud (€7/Monat) ⭐ RECOMMENDED

**Schritte:**

1. **VPS mieten**
   ```bash
   # Hetzner Cloud: https://console.hetzner.cloud
   # - CPX11 (2vCPU, 4GB RAM, 40GB SSD) = €7.16/Monat
   # - Ubuntu 22.04 LTS
   # - SSH Key registrieren
   ```

2. **SSH Login**
   ```bash
   ssh root@your_vps_ip
   ```

3. **Docker installieren**
   ```bash
   curl -fsSL https://get.docker.com -o get-docker.sh
   sudo sh get-docker.sh
   sudo usermod -aG docker root
   ```

4. **Repository klonen**
   ```bash
   git clone https://github.com/your-repo/ki-disposition.git
   cd ki-disposition
   cp .env.example .env
   ```

5. **Environment anpassen**
   ```bash
   # Edit .env for production
   nano .env
   
   # Wichtig ändern:
   # - NODE_ENV=production
   # - DB_PASSWORD=very_strong_password
   # - FRONTEND_URL=https://your-domain.com
   # - JWT_SECRET=random_secret
   ```

6. **SSL Certificate (Let's Encrypt)**
   ```bash
   sudo apt update && sudo apt install certbot
   sudo certbot certonly --standalone -d your-domain.com
   ```

7. **Docker Compose up**
   ```bash
   docker-compose -f docker-compose.yml up -d
   
   # Check status
   docker-compose ps
   docker-compose logs -f
   ```

8. **Nginx Reverse Proxy (optional)**
   ```nginx
   server {
       listen 443 ssl;
       server_name your-domain.com;
       
       ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
       ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;
       
       location / {
           proxy_pass http://localhost:3001;
           proxy_http_version 1.1;
           proxy_set_header Upgrade $http_upgrade;
           proxy_set_header Connection 'upgrade';
           proxy_set_header Host $host;
           proxy_cache_bypass $http_upgrade;
       }
       
       location /api {
           proxy_pass http://localhost:3000;
           proxy_http_version 1.1;
           proxy_set_header Upgrade $http_upgrade;
           proxy_set_header Connection 'upgrade';
           proxy_set_header Host $host;
           proxy_cache_bypass $http_upgrade;
       }
   }
   ```

9. **Monitoring**
   ```bash
   # View logs
   docker-compose logs -f
   
   # Monitor disk usage
   df -h
   
   # Monitor system
   docker stats
   ```

10. **Backup Strategy**
    ```bash
    # Daily backup cron job
    0 2 * * * cd /root/ki-disposition && docker-compose exec -T postgres pg_dump -U kidb ki_disposition | gzip > /backups/db_$(date +\%Y\%m\%d_\%H\%M\%S).sql.gz
    ```

---

### Option B: Railway.app (€5-50/Monat)

1. Connect GitHub repo to Railway
2. Set environment variables in Railway dashboard
3. Deploy (auto-deploys on git push)
4. Configure PostgreSQL in Railway
5. Done! Auto-scaling included

**Pros:** 
- Zero ops
- Auto-scaling
- Git push to deploy

**Cons:**
- Vendor lock-in
- More expensive at scale

---

### Option C: DigitalOcean (€4-12/Monat)

Similar to Hetzner, but:
- Better UI
- Built-in backups (€1-2/month extra)
- App Platform (managed deployments)

---

## 🔐 Production Checklist

- [ ] Change all passwords in .env
- [ ] Enable HTTPS/SSL
- [ ] Setup firewall (only ports 80, 443, SSH)
- [ ] Enable database backups (daily)
- [ ] Monitor logs and errors
- [ ] Setup uptime monitoring (UptimeRobot free)
- [ ] Configure email alerts for failures
- [ ] Regular security updates (`docker pull` latest images)
- [ ] Setup log rotation (prevent disk full)

---

## 📊 Monitoring Setup

### 1. Log Aggregation (free)
```bash
# Use Docker's logging driver
docker-compose logs -f --tail 100
```

### 2. Error Monitoring (free)
```bash
# Setup error tracking to file
cat > backend/error-reporter.js << 'EOF'
const fs = require('fs');
const path = require('path');

const errorLog = path.join('/var/log', 'ki-disposition-errors.log');

process.on('uncaughtException', (err) => {
  fs.appendFileSync(errorLog, `${new Date()}: ${err.stack}\n`);
  console.error(err);
  process.exit(1);
});
EOF
```

### 3. Uptime Monitoring (free)
- Use UptimeRobot: Add http check to `/api/health`
- Get notified if API goes down

### 4. Performance Monitoring
```bash
# Enable PostgreSQL query logging
# In .env:
POSTGRES_INITDB_ARGS="-c log_statement=all"
```

---

## 🚨 Troubleshooting

### Services won't start?
```bash
# Check logs
docker-compose logs postgres
docker-compose logs backend
docker-compose logs frontend

# Restart
docker-compose restart
```

### Out of disk space?
```bash
# Check usage
docker system df

# Clean up
docker system prune -a
docker volume prune
```

### Database connection errors?
```bash
# Check DB
docker-compose exec postgres psql -U kidb -d ki_disposition -c "SELECT 1"

# Check connectivity
docker-compose exec backend nc -zv postgres 5432
```

### Slow routes optimization?
```bash
# Check OR-Tools timeout in .env
OPTIMIZATION_TIMEOUT_SECONDS=30

# Check resources
docker stats backend
```

---

## 💰 Estimated Monthly Costs (Production)

| Item | Hetzner | Railway | Digital Ocean |
|------|---------|---------|---------------|
| VPS/Compute | €7 | €10 | €5 |
| Database | 0* | €15 | €10 |
| Storage | 0* | 0 | $1-3 |
| Backups | 0* | included | $1-2 |
| **Total** | **~€7/mo** | **~€25/mo** | **~€16/mo** |

*Included in VPS

**Recommended for MVP:** Hetzner (~€7/mo)
**Recommended for growth:** Railway (~€25/mo) - less ops overhead

---

## 🔄 CI/CD Pipeline (GitHub Actions)

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy to Production

on:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Deploy to Hetzner
        env:
          SSH_PRIVATE_KEY: ${{ secrets.DEPLOY_KEY }}
          HOST: ${{ secrets.DEPLOY_HOST }}
        run: |
          mkdir -p ~/.ssh
          echo "$SSH_PRIVATE_KEY" > ~/.ssh/deploy_key
          chmod 600 ~/.ssh/deploy_key
          ssh -i ~/.ssh/deploy_key root@$HOST 'cd /root/ki-disposition && git pull && docker-compose up -d'
```

---

## 📞 Support

Having issues? Check logs first:
```bash
docker-compose logs -f
```

Common problems:
1. **DB won't start:** Check permissions on data directories
2. **API returns 500:** Check backend logs
3. **Frontend blank:** Check browser console
4. **Slow optimization:** Increase `OPTIMIZATION_TIMEOUT_SECONDS`

---

**Last updated:** 2026-09-29
