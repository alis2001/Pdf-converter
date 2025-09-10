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
    service: 'api-gateway',
    timestamp: new Date().toISOString()
  });
});

// Basic welcome
app.get('/', (req, res) => {
  res.json({
    message: 'PDF Converter API Gateway',
    status: 'running'
  });
});

// Simple API endpoints (placeholder)
app.get('/api/v1/status', (req, res) => {
  res.json({
    service: 'api-gateway',
    status: 'operational',
    version: '1.0.0'
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`🚀 API Gateway running on port ${PORT}`);
  console.log(`📊 Health check: http://localhost:${PORT}/health`);
});