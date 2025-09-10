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
    service: 'file-service',
    timestamp: new Date().toISOString()
  });
});

// Basic service info
app.get('/', (req, res) => {
  res.json({
    message: 'PDF Converter File Service',
    status: 'running',
    version: '1.0.0'
  });
});

// Simple status endpoint
app.get('/status', (req, res) => {
  res.json({
    service: 'file-service',
    status: 'operational',
    version: '1.0.0',
    features: ['upload', 'download', 'mobile-ready', 'minio-storage']
  });
});

// Placeholder file endpoints (will implement later)
app.post('/upload', (req, res) => {
  res.status(501).json({
    message: 'File upload endpoint - coming soon',
    service: 'file-service'
  });
});

app.get('/files', (req, res) => {
  res.status(501).json({
    message: 'File list endpoint - coming soon',
    service: 'file-service'
  });
});

app.get('/files/:id', (req, res) => {
  res.status(501).json({
    message: 'File details endpoint - coming soon',
    service: 'file-service',
    fileId: req.params.id
  });
});

app.get('/files/:id/download', (req, res) => {
  res.status(501).json({
    message: 'File download endpoint - coming soon',
    service: 'file-service',
    fileId: req.params.id
  });
});

app.delete('/files/:id', (req, res) => {
  res.status(501).json({
    message: 'File delete endpoint - coming soon',
    service: 'file-service',
    fileId: req.params.id
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`📁 File Service running on port ${PORT}`);
  console.log(`📊 Health check: http://localhost:${PORT}/health`);
});