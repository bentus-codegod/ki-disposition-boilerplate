import React, { useState, useEffect } from 'react';
import { MapContainer, TileLayer, Marker, Popup, Polyline } from 'react-leaflet';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend } from 'recharts';
import L from 'leaflet';
import io from 'socket.io-client';
import axios from 'axios';

// Fix Leaflet icon issue
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.3.1/images/marker-icon-2x.png',
  iconUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.3.1/images/marker-icon.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.3.1/images/marker-shadow.png',
});

const App = () => {
  const [routes, setRoutes] = useState([]);
  const [tasks, setTasks] = useState([]);
  const [vehicles, setVehicles] = useState([]);
  const [selectedRoute, setSelectedRoute] = useState(null);
  const [stats, setStats] = useState({
    total_routes: 0,
    total_distance: 0,
    total_duration: 0,
    optimization_quality: 0
  });
  const [socket, setSocket] = useState(null);
  const [loading, setLoading] = useState(true);

  // Connect to Backend WebSocket
  useEffect(() => {
    const newSocket = io('http://localhost:3000', {
      reconnection: true,
      reconnectionDelay: 1000,
      reconnectionDelayMax: 5000
    });

    newSocket.on('connect', () => {
      console.log('Connected to server');
    });

    newSocket.on('routes:optimized', (data) => {
      console.log('Routes optimized:', data);
      setStats({
        total_routes: data.routes.length,
        total_distance: data.total_distance,
        total_duration: data.total_duration,
        optimization_quality: data.optimization_quality
      });
    });

    newSocket.on('gps:update', (data) => {
      console.log('GPS Update:', data);
      setVehicles(prev => prev.map(v =>
        v.id === data.driver_id ? { ...v, lat: data.lat, lng: data.lng } : v
      ));
    });

    newSocket.on('task:completed', (data) => {
      setTasks(prev => prev.map(t =>
        t.id === data.task_id ? { ...t, status: 'completed' } : t
      ));
    });

    setSocket(newSocket);
    return () => newSocket.close();
  }, []);

  // Fetch initial data
  useEffect(() => {
    const fetchData = async () => {
      try {
        const [routesRes, tasksRes, vehiclesRes] = await Promise.all([
          axios.get('http://localhost:3000/api/routes'),
          axios.get('http://localhost:3000/api/tasks'),
          axios.get('http://localhost:3000/api/vehicles')
        ]);

        setRoutes(routesRes.data.data || []);
        setTasks(tasksRes.data.data || []);
        setVehicles(vehiclesRes.data.data || []);
        setLoading(false);
      } catch (err) {
        console.error('Error fetching data:', err);
        setLoading(false);
      }
    };

    fetchData();
  }, []);

  const handleOptimizeRoutes = async () => {
    try {
      const vehicleIds = vehicles.map(v => v.id);
      const taskIds = tasks.filter(t => t.status === 'pending').map(t => t.id);

      if (vehicleIds.length === 0 || taskIds.length === 0) {
        alert('No vehicles or tasks available for optimization');
        return;
      }

      const response = await axios.post('http://localhost:3000/api/routes/optimize', {
        vehicle_ids: vehicleIds,
        task_ids: taskIds
      });

      console.log('Optimization result:', response.data);
    } catch (err) {
      console.error('Error optimizing routes:', err);
      alert('Error optimizing routes');
    }
  };

  if (loading) {
    return <div className="flex items-center justify-center h-screen">Loading...</div>;
  }

  return (
    <div className="bg-gray-100 min-h-screen">
      {/* Header */}
      <header className="bg-blue-600 text-white p-4 shadow">
        <div className="max-w-7xl mx-auto flex justify-between items-center">
          <h1 className="text-3xl font-bold">KI-Disposition</h1>
          <div className="flex gap-4">
            <button
              onClick={handleOptimizeRoutes}
              className="bg-green-500 hover:bg-green-700 text-white font-bold py-2 px-4 rounded"
            >
              🚀 Optimiere Routen
            </button>
          </div>
        </div>
      </header>

      <div className="max-w-7xl mx-auto p-4">
        {/* Stats */}
        <div className="grid grid-cols-4 gap-4 mb-6">
          <div className="bg-white p-4 rounded shadow">
            <p className="text-gray-600 text-sm">Routen</p>
            <p className="text-3xl font-bold">{routes.length}</p>
          </div>
          <div className="bg-white p-4 rounded shadow">
            <p className="text-gray-600 text-sm">Gesamt Distanz</p>
            <p className="text-3xl font-bold">{stats.total_distance.toFixed(1)} km</p>
          </div>
          <div className="bg-white p-4 rounded shadow">
            <p className="text-gray-600 text-sm">Gesamt Zeit</p>
            <p className="text-3xl font-bold">{(stats.total_duration / 60).toFixed(1)} h</p>
          </div>
          <div className="bg-white p-4 rounded shadow">
            <p className="text-gray-600 text-sm">Optimierungsqualität</p>
            <p className="text-3xl font-bold">{(stats.optimization_quality * 100).toFixed(0)}%</p>
          </div>
        </div>

        {/* Map + Tasks */}
        <div className="grid grid-cols-3 gap-4 mb-6">
          {/* Map */}
          <div className="col-span-2 bg-white p-4 rounded shadow h-96">
            <MapContainer center={[51.1657, 10.4515]} zoom={6} style={{ height: '100%', width: '100%' }}>
              <TileLayer
                url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
                attribution='&copy; OpenStreetMap contributors'
              />
              {vehicles.map(vehicle => (
                <Marker key={vehicle.id} position={[vehicle.lat || 51.1657, vehicle.lng || 10.4515]}>
                  <Popup>
                    <div>
                      <p><strong>{vehicle.name}</strong></p>
                      <p>Status: {vehicle.status}</p>
                      <p>Capacity: {vehicle.current_load}/{vehicle.capacity}</p>
                    </div>
                  </Popup>
                </Marker>
              ))}
            </MapContainer>
          </div>

          {/* Tasks List */}
          <div className="bg-white p-4 rounded shadow overflow-y-auto h-96">
            <h3 className="text-lg font-bold mb-4">Aufgaben ({tasks.length})</h3>
            <div className="space-y-2">
              {tasks.slice(0, 10).map(task => (
                <div
                  key={task.id}
                  className={`p-2 rounded border cursor-pointer ${
                    task.status === 'completed' ? 'bg-green-100' :
                    task.status === 'failed' ? 'bg-red-100' :
                    task.status === 'in_progress' ? 'bg-blue-100' :
                    'bg-gray-100'
                  }`}
                  onClick={() => setSelectedRoute(task.id)}
                >
                  <p className="font-semibold">{task.customer_id}</p>
                  <p className="text-sm text-gray-600">Status: {task.status}</p>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* Vehicles */}
        <div className="bg-white p-4 rounded shadow mb-6">
          <h3 className="text-lg font-bold mb-4">Fahrzeuge ({vehicles.length})</h3>
          <div className="grid grid-cols-4 gap-4">
            {vehicles.map(vehicle => (
              <div key={vehicle.id} className="border p-3 rounded">
                <p className="font-semibold">{vehicle.name}</p>
                <p className="text-sm text-gray-600">📍 {vehicle.status}</p>
                <p className="text-sm">📦 {vehicle.current_load}/{vehicle.capacity}</p>
                <p className="text-xs text-gray-400 mt-1">ID: {vehicle.id}</p>
              </div>
            ))}
          </div>
        </div>

        {/* Performance Chart */}
        <div className="bg-white p-4 rounded shadow">
          <h3 className="text-lg font-bold mb-4">Performance-Trend</h3>
          <LineChart width={700} height={300} data={[
            { time: '08:00', efficiency: 65 },
            { time: '09:00', efficiency: 72 },
            { time: '10:00', efficiency: 78 },
            { time: '11:00', efficiency: 85 },
            { time: '12:00', efficiency: 88 }
          ]}>
            <CartesianGrid strokeDasharray="3 3" />
            <XAxis dataKey="time" />
            <YAxis />
            <Tooltip />
            <Legend />
            <Line type="monotone" dataKey="efficiency" stroke="#8884d8" name="Auslastung %" />
          </LineChart>
        </div>
      </div>
    </div>
  );
};

export default App;
