const express = require('express');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Basic middleware
app.use(express.json());

// Health check - required for Docker Compose
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    service: 'auth-service',
    timestamp: new Date().toISOString()
  });
});

// Basic service info
app.get('/', (req, res) => {
  res.json({
    message: 'PDF Converter Auth Service',
    status: 'running',
    version: '1.0.0'
  });
});

// Simple status endpoint
app.get('/status', (req, res) => {
  res.json({
    service: 'auth-service',
    status: 'operational',
    version: '1.0.0',
    features: ['jwt', 'mobile-ready']
  });
});

// Placeholder auth endpoints (will implement later)
app.post('/register', (req, res) => {
  res.status(501).json({
    message: 'Registration endpoint - coming soon',
    service: 'auth-service'
  });
});

app.post('/login', (req, res) => {
  res.status(501).json({
    message: 'Login endpoint - coming soon',
    service: 'auth-service'
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`🔐 Auth Service running on port ${PORT}`);
  console.log(`📊 Health check: http://localhost:${PORT}/health`);
});