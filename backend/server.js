const express = require('express');
const cors = require('express-cors');
const http = require('http');
const socketIo = require('socket.io');
const dotenv = require('dotenv');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const winston = require('winston');
const { Pool } = require('pg');

// Load environment variables
dotenv.config();

// Initialize Express
const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: { origin: process.env.FRONTEND_URL || 'http://localhost:3001', methods: ['GET', 'POST'] }
});

// Logger setup
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.json(),
  transports: [
    new winston.transports.Console(),
    new winston.transports.File({ filename: 'error.log', level: 'error' }),
    new winston.transports.File({ filename: 'combined.log' })
  ]
});

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json());

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100
});
app.use('/api/', limiter);

// PostgreSQL Connection Pool
const pool = new Pool({
  user: process.env.DB_USER || 'kidb',
  password: process.env.DB_PASSWORD || 'ki_pass_dev',
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME || 'ki_disposition'
});

pool.on('error', (err) => {
  logger.error('Unexpected error on idle client', err);
});

// Health Check
app.get('/api/health', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date(),
    uptime: process.uptime()
  });
});

// ============================================================
// ROUTES API
// ============================================================

// GET /api/routes - List all routes
app.get('/api/routes', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM routes WHERE deleted_at IS NULL ORDER BY created_at DESC LIMIT 100'
    );
    res.json({
      success: true,
      data: result.rows,
      count: result.rows.length
    });
  } catch (err) {
    logger.error('Error fetching routes:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// POST /api/routes/optimize - Optimize routes using OR-Tools
app.post('/api/routes/optimize', async (req, res) => {
  try {
    const { vehicle_ids, task_ids } = req.body;

    if (!vehicle_ids || !task_ids) {
      return res.status(400).json({
        success: false,
        error: 'vehicle_ids and task_ids required'
      });
    }

    // TODO: Implement OR-Tools VRP solver
    // For now, return mock optimized routes
    const optimizedRoutes = {
      routes: [
        {
          vehicle_id: vehicle_ids[0],
          optimized_tasks: task_ids.slice(0, 5),
          estimated_duration: 180,
          estimated_distance: 45.3
        }
      ],
      total_duration: 180,
      total_distance: 45.3,
      optimization_quality: 0.85
    };

    // Broadcast to dispatcher
    io.emit('routes:optimized', optimizedRoutes);

    res.json({
      success: true,
      data: optimizedRoutes
    });
  } catch (err) {
    logger.error('Error optimizing routes:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ============================================================
// TASKS API
// ============================================================

// GET /api/tasks - List all tasks
app.get('/api/tasks', async (req, res) => {
  try {
    const { status, route_id } = req.query;
    let query = 'SELECT * FROM tasks WHERE deleted_at IS NULL';
    const params = [];

    if (status) {
      query += ' AND status = $1';
      params.push(status);
    }
    if (route_id) {
      query += ' AND route_id = $' + (params.length + 1);
      params.push(route_id);
    }

    query += ' ORDER BY created_at DESC LIMIT 500';
    const result = await pool.query(query, params);

    res.json({
      success: true,
      data: result.rows,
      count: result.rows.length
    });
  } catch (err) {
    logger.error('Error fetching tasks:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// POST /api/tasks - Create new task
app.post('/api/tasks', async (req, res) => {
  try {
    const { customer_id, pickup_location, delivery_location, time_window } = req.body;

    const result = await pool.query(
      `INSERT INTO tasks (customer_id, pickup_lat, pickup_lng, delivery_lat, delivery_lng, time_window_start, time_window_end, status, created_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, 'pending', NOW())
       RETURNING *`,
      [customer_id, pickup_location.lat, pickup_location.lng, delivery_location.lat, delivery_location.lng, time_window.start, time_window.end]
    );

    // Broadcast new task to dispatcher
    io.emit('tasks:new', result.rows[0]);

    res.status(201).json({
      success: true,
      data: result.rows[0]
    });
  } catch (err) {
    logger.error('Error creating task:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ============================================================
// VEHICLES API
// ============================================================

// GET /api/vehicles - List all vehicles
app.get('/api/vehicles', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM vehicles WHERE deleted_at IS NULL ORDER BY created_at DESC'
    );
    res.json({
      success: true,
      data: result.rows,
      count: result.rows.length
    });
  } catch (err) {
    logger.error('Error fetching vehicles:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ============================================================
// REAL-TIME UPDATES VIA WEBSOCKET
// ============================================================

io.on('connection', (socket) => {
  logger.info(`Client connected: ${socket.id}`);

  socket.on('disconnect', () => {
    logger.info(`Client disconnected: ${socket.id}`);
  });

  // Fahrer sendet GPS Update
  socket.on('gps:update', (data) => {
    // TODO: Save to database
    logger.info(`GPS Update from ${data.driver_id}:`, data);

    // Broadcast to dispatcher
    io.emit('gps:update', data);
  });

  // Fahrer bestätigt Task
  socket.on('task:complete', async (data) => {
    try {
      await pool.query(
        'UPDATE tasks SET status = $1, completed_at = NOW() WHERE id = $2',
        ['completed', data.task_id]
      );

      // Broadcast completion
      io.emit('task:completed', data);

      logger.info(`Task completed: ${data.task_id}`);
    } catch (err) {
      logger.error('Error completing task:', err);
    }
  });

  // Fehlerfahrt melden
  socket.on('task:failed', async (data) => {
    try {
      await pool.query(
        'UPDATE tasks SET status = $1, failure_reason = $2, failed_at = NOW() WHERE id = $3',
        ['failed', data.reason, data.task_id]
      );

      // Trigger re-optimization
      io.emit('task:failed', data);
      logger.info(`Task failed: ${data.task_id} - Reason: ${data.reason}`);
    } catch (err) {
      logger.error('Error marking task as failed:', err);
    }
  });
});

// ============================================================
// ERROR HANDLING
// ============================================================

app.use((err, req, res, next) => {
  logger.error('Unhandled error:', err);
  res.status(500).json({
    success: false,
    error: 'Internal Server Error',
    message: process.env.NODE_ENV === 'development' ? err.message : undefined
  });
});

// ============================================================
// START SERVER
// ============================================================

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  logger.info(`🚀 KI-Disposition Backend running on port ${PORT}`);
  logger.info(`📍 Environment: ${process.env.NODE_ENV || 'development'}`);
  logger.info(`🗄️  Database: ${process.env.DB_HOST}:${process.env.DB_PORT}/${process.env.DB_NAME}`);
});

module.exports = { app, io };
