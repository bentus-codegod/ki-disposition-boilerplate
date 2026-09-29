-- KI-Disposition Database Schema
-- PostgreSQL with PostGIS

-- Create Extensions
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS uuid-ossp;

-- ============================================================
-- CUSTOMERS
-- ============================================================
CREATE TABLE customers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name VARCHAR(255) NOT NULL,
  email VARCHAR(255),
  phone VARCHAR(20),
  city VARCHAR(100),
  country VARCHAR(100),
  status VARCHAR(50) DEFAULT 'active',
  created_at TIMESTAMP DEFAULT NOW(),
  deleted_at TIMESTAMP
);

-- ============================================================
-- VEHICLES
-- ============================================================
CREATE TABLE vehicles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  customer_id UUID REFERENCES customers(id),
  name VARCHAR(100) NOT NULL,
  plate VARCHAR(20) UNIQUE,
  status VARCHAR(50) DEFAULT 'available',
  capacity INTEGER DEFAULT 100,
  current_load INTEGER DEFAULT 0,
  lat DECIMAL(10, 8),
  lng DECIMAL(11, 8),
  last_update TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  deleted_at TIMESTAMP
);

-- Create index for faster geo queries
CREATE INDEX idx_vehicles_location ON vehicles USING GIST(
  ST_Point(lng, lat)
);

-- ============================================================
-- DRIVERS
-- ============================================================
CREATE TABLE drivers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  vehicle_id UUID REFERENCES vehicles(id),
  name VARCHAR(100) NOT NULL,
  phone VARCHAR(20),
  status VARCHAR(50) DEFAULT 'available',
  total_hours INTEGER DEFAULT 0,
  failed_deliveries INTEGER DEFAULT 0,
  success_rate DECIMAL(5, 2) DEFAULT 100.00,
  created_at TIMESTAMP DEFAULT NOW(),
  deleted_at TIMESTAMP
);

-- ============================================================
-- TASKS (Aufträge/Stops)
-- ============================================================
CREATE TABLE tasks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  customer_id UUID REFERENCES customers(id),
  route_id UUID,
  vehicle_id UUID REFERENCES vehicles(id),
  driver_id UUID REFERENCES drivers(id),
  status VARCHAR(50) DEFAULT 'pending',

  -- Location
  pickup_lat DECIMAL(10, 8),
  pickup_lng DECIMAL(11, 8),
  delivery_lat DECIMAL(10, 8),
  delivery_lng DECIMAL(11, 8),

  -- Time Windows
  time_window_start TIMESTAMP,
  time_window_end TIMESTAMP,
  estimated_arrival TIMESTAMP,
  estimated_completion TIMESTAMP,

  -- Execution
  actual_arrival TIMESTAMP,
  actual_completion TIMESTAMP,
  completed_at TIMESTAMP,
  failed_at TIMESTAMP,
  failure_reason VARCHAR(255),

  -- Metadata
  priority INTEGER DEFAULT 0,
  weight DECIMAL(10, 2),
  volume DECIMAL(10, 2),
  notes TEXT,

  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  deleted_at TIMESTAMP
);

-- Indexes for fast queries
CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_tasks_route_id ON tasks(route_id);
CREATE INDEX idx_tasks_vehicle_id ON tasks(vehicle_id);
CREATE INDEX idx_tasks_location_delivery ON tasks USING GIST(
  ST_Point(delivery_lng, delivery_lat)
);

-- ============================================================
-- ROUTES
-- ============================================================
CREATE TABLE routes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  vehicle_id UUID REFERENCES vehicles(id),
  driver_id UUID REFERENCES drivers(id),
  status VARCHAR(50) DEFAULT 'planned',

  -- Route Stats
  total_distance DECIMAL(10, 2),
  total_duration INTEGER,
  total_tasks INTEGER,
  completed_tasks INTEGER DEFAULT 0,
  failed_tasks INTEGER DEFAULT 0,

  -- Optimization
  optimization_quality DECIMAL(5, 2),
  is_optimized BOOLEAN DEFAULT FALSE,
  optimized_at TIMESTAMP,

  -- Execution
  started_at TIMESTAMP,
  completed_at TIMESTAMP,

  -- Metadata
  date_planned DATE,
  notes TEXT,

  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  deleted_at TIMESTAMP
);

CREATE INDEX idx_routes_vehicle_id ON routes(vehicle_id);
CREATE INDEX idx_routes_status ON routes(status);
CREATE INDEX idx_routes_date_planned ON routes(date_planned);

-- ============================================================
-- ROUTE TASKS (Junction Table)
-- ============================================================
CREATE TABLE route_tasks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  route_id UUID NOT NULL REFERENCES routes(id) ON DELETE CASCADE,
  task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  sequence_number INTEGER,
  created_at TIMESTAMP DEFAULT NOW(),

  UNIQUE(route_id, task_id)
);

CREATE INDEX idx_route_tasks_route_id ON route_tasks(route_id);
CREATE INDEX idx_route_tasks_task_id ON route_tasks(task_id);

-- ============================================================
-- GPS TRACKING (Real-time Driver Location)
-- ============================================================
CREATE TABLE gps_tracking (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  vehicle_id UUID NOT NULL REFERENCES vehicles(id),
  driver_id UUID NOT NULL REFERENCES drivers(id),
  lat DECIMAL(10, 8) NOT NULL,
  lng DECIMAL(11, 8) NOT NULL,
  speed DECIMAL(5, 2),
  heading DECIMAL(6, 2),
  accuracy DECIMAL(5, 2),
  recorded_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_gps_tracking_vehicle_id ON gps_tracking(vehicle_id);
CREATE INDEX idx_gps_tracking_recorded_at ON gps_tracking(recorded_at DESC);
CREATE INDEX idx_gps_tracking_location ON gps_tracking USING GIST(
  ST_Point(lng, lat)
);

-- ============================================================
-- OPTIMIZATION HISTORY (for analysis)
-- ============================================================
CREATE TABLE optimization_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  route_id UUID REFERENCES routes(id),
  vehicle_count INTEGER,
  task_count INTEGER,
  optimization_quality DECIMAL(5, 2),
  execution_time_ms INTEGER,
  total_distance DECIMAL(10, 2),
  total_duration INTEGER,
  failure_count INTEGER DEFAULT 0,
  notes TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_optimization_history_route_id ON optimization_history(route_id);
CREATE INDEX idx_optimization_history_created_at ON optimization_history(created_at DESC);

-- ============================================================
-- ALERTS (for failures and anomalies)
-- ============================================================
CREATE TABLE alerts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  alert_type VARCHAR(50),
  severity VARCHAR(20),
  vehicle_id UUID REFERENCES vehicles(id),
  driver_id UUID REFERENCES drivers(id),
  task_id UUID REFERENCES tasks(id),
  message TEXT,
  is_resolved BOOLEAN DEFAULT FALSE,
  resolved_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  deleted_at TIMESTAMP
);

CREATE INDEX idx_alerts_severity ON alerts(severity);
CREATE INDEX idx_alerts_created_at ON alerts(created_at DESC);
CREATE INDEX idx_alerts_vehicle_id ON alerts(vehicle_id);

-- ============================================================
-- Sample Data
-- ============================================================

-- Insert sample customer
INSERT INTO customers (name, email, phone, city, country) VALUES
  ('Otto Dörner GmbH', 'contact@otto-doerner.de', '+49 123 456789', 'Hamburg', 'Germany'),
  ('Der Sack', 'info@der-sack.de', '+49 987 654321', 'Munich', 'Germany');

-- Insert sample vehicles
INSERT INTO vehicles (customer_id, name, plate, capacity) VALUES
  ((SELECT id FROM customers WHERE name = 'Otto Dörner GmbH'), 'Van-01', 'HH-KI-001', 100),
  ((SELECT id FROM customers WHERE name = 'Otto Dörner GmbH'), 'Van-02', 'HH-KI-002', 100);

-- Insert sample drivers
INSERT INTO drivers (vehicle_id, name, phone) VALUES
  ((SELECT id FROM vehicles WHERE plate = 'HH-KI-001'), 'Max Müller', '+49 123 111111'),
  ((SELECT id FROM vehicles WHERE plate = 'HH-KI-002'), 'Anna Schmidt', '+49 123 222222');

-- Insert sample tasks
INSERT INTO tasks (customer_id, pickup_lat, pickup_lng, delivery_lat, delivery_lng, priority, status) VALUES
  ((SELECT id FROM customers WHERE name = 'Otto Dörner GmbH'), 53.5511, 10.0079, 53.6, 10.1, 1, 'pending'),
  ((SELECT id FROM customers WHERE name = 'Otto Dörner GmbH'), 53.5511, 10.0079, 53.55, 10.05, 2, 'pending'),
  ((SELECT id FROM customers WHERE name = 'Otto Dörner GmbH'), 53.5511, 10.0079, 53.65, 10.15, 3, 'pending');

-- ============================================================
-- Views for Analytics
-- ============================================================

-- Daily Performance Dashboard
CREATE VIEW daily_performance AS
SELECT
  DATE(routes.created_at) as date,
  COUNT(DISTINCT routes.id) as total_routes,
  COUNT(DISTINCT routes.vehicle_id) as active_vehicles,
  SUM(routes.total_tasks) as total_tasks,
  SUM(routes.completed_tasks) as completed_tasks,
  SUM(routes.total_distance) as total_distance,
  ROUND(AVG(routes.optimization_quality), 2) as avg_optimization_quality,
  COUNT(CASE WHEN routes.status = 'completed' THEN 1 END) as completed_routes
FROM routes
WHERE deleted_at IS NULL
GROUP BY DATE(routes.created_at);

-- Driver Performance
CREATE VIEW driver_performance AS
SELECT
  d.id,
  d.name,
  COUNT(t.id) as total_tasks,
  COUNT(CASE WHEN t.status = 'completed' THEN 1 END) as completed_tasks,
  COUNT(CASE WHEN t.status = 'failed' THEN 1 END) as failed_tasks,
  ROUND(
    CASE
      WHEN COUNT(t.id) > 0
      THEN (COUNT(CASE WHEN t.status = 'completed' THEN 1 END) * 100.0 / COUNT(t.id))
      ELSE 0
    END,
    2
  ) as success_rate
FROM drivers d
LEFT JOIN tasks t ON d.id = t.driver_id AND t.deleted_at IS NULL
WHERE d.deleted_at IS NULL
GROUP BY d.id, d.name;

-- Geographic Coverage
CREATE VIEW geographic_coverage AS
SELECT
  c.id,
  c.name,
  COUNT(DISTINCT v.id) as vehicle_count,
  COUNT(DISTINCT t.id) as task_count,
  ST_AsText(ST_Extent(ST_Point(t.delivery_lng, t.delivery_lat))) as coverage_area
FROM customers c
LEFT JOIN vehicles v ON c.id = v.customer_id
LEFT JOIN tasks t ON v.id = t.vehicle_id
WHERE c.deleted_at IS NULL AND v.deleted_at IS NULL
GROUP BY c.id, c.name;

-- ============================================================
-- Summary Statistics
-- ============================================================
COMMENT ON TABLE customers IS 'Logistik-Partner (z.B. Otto Dörner, Der Sack)';
COMMENT ON TABLE vehicles IS 'Fahrzeuge pro Kunde';
COMMENT ON TABLE tasks IS 'Einzelne Transportaufträge/Stopps';
COMMENT ON TABLE routes IS 'Geplante Fahrtrouten';
COMMENT ON TABLE gps_tracking IS 'Echtzeit GPS-Tracking der Fahrer';
COMMENT ON TABLE alerts IS 'Fehler und Anomalien';

-- Confirm Setup
SELECT 'KI-Disposition Database initialized successfully!' as status;
