// applications/analytics-api/server.js
// Nimbus Analytics - Core Analytics API Service
// Security-hardened Node.js application for handling client data analytics

const express = require('express');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const cors = require('cors');
const morgan = require('morgan');
const { v4: uuidv4 } = require('uuid');

const app = express();
const PORT = process.env.PORT || 3000;
const NODE_ENV = process.env.NODE_ENV || 'production';

// Security middleware - Defense in depth
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"],
    },
  },
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
    preload: true
  }
}));

// Rate limiting - Prevent abuse
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP, please try again later.',
  standardHeaders: true,
  legacyHeaders: false,
});
app.use(limiter);

// CORS configuration
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || ['https://nimbus-dashboard.com'],
  credentials: true,
  optionsSuccessStatus: 200
}));

// Request parsing and logging
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));
app.use(morgan('combined'));

// Request ID middleware for tracing
app.use((req, res, next) => {
  req.id = uuidv4();
  res.setHeader('X-Request-ID', req.id);
  next();
});

// Health check endpoint - Required for container orchestration
app.get('/health', (req, res) => {
  const health = {
    uptime: process.uptime(),
    message: 'OK',
    timestamp: Date.now(),
    service: 'analytics-api',
    version: process.env.SERVICE_VERSION || '1.0.0',
    environment: NODE_ENV
  };
  
  try {
    res.status(200).json(health);
  } catch (error) {
    health.message = 'ERROR';
    res.status(503).json(health);
  }
});

// Ready check endpoint - Kubernetes readiness probe
app.get('/ready', (req, res) => {
  // Add actual readiness checks here (database connections, etc.)
  const ready = {
    status: 'ready',
    timestamp: Date.now(),
    checks: {
      database: 'connected',
      cache: 'connected',
      external_api: 'available'
    }
  };
  res.status(200).json(ready);
});

// Security headers endpoint - For security scanning
app.get('/security-headers', (req, res) => {
  res.json({
    'Content-Security-Policy': res.getHeader('Content-Security-Policy'),
    'Strict-Transport-Security': res.getHeader('Strict-Transport-Security'),
    'X-Content-Type-Options': res.getHeader('X-Content-Type-Options'),
    'X-Frame-Options': res.getHeader('X-Frame-Options'),
    'X-XSS-Protection': res.getHeader('X-XSS-Protection')
  });
});

// Analytics endpoints
app.get('/api/v1/analytics/summary', async (req, res) => {
  try {
    // Simulate data processing with security logging
    console.log(`[${req.id}] Analytics summary requested by IP: ${req.ip}`);
    
    const summary = {
      total_users: 12450,
      active_sessions: 234,
      data_processed_mb: 1024,
      last_updated: new Date().toISOString(),
      request_id: req.id
    };
    
    res.json(summary);
  } catch (error) {
    console.error(`[${req.id}] Error generating analytics summary:`, error);
    res.status(500).json({
      error: 'Internal server error',
      request_id: req.id,
      timestamp: Date.now()
    });
  }
});

app.post('/api/v1/analytics/process', async (req, res) => {
  try {
    const { dataset, filters } = req.body;
    
    // Input validation - Prevent injection attacks
    if (!dataset || typeof dataset !== 'string' || dataset.length > 100) {
      return res.status(400).json({
        error: 'Invalid dataset parameter',
        request_id: req.id
      });
    }
    
    console.log(`[${req.id}] Processing dataset: ${dataset}`);
    
    // Simulate data processing
    await new Promise(resolve => setTimeout(resolve, 100));
    
    const result = {
      dataset,
      status: 'processed',
      results: {
        records_processed: Math.floor(Math.random() * 10000),
        processing_time_ms: Math.floor(Math.random() * 1000),
        anomalies_detected: Math.floor(Math.random() * 5)
      },
      request_id: req.id,
      timestamp: Date.now()
    };
    
    res.json(result);
  } catch (error) {
    console.error(`[${req.id}] Error processing analytics:`, error);
    res.status(500).json({
      error: 'Processing failed',
      request_id: req.id
    });
  }
});

// 404 handler
app.use('*', (req, res) => {
  console.log(`[${req.id}] 404 - Route not found: ${req.method} ${req.originalUrl}`);
  res.status(404).json({
    error: 'Route not found',
    request_id: req.id
  });
});

// Global error handler
app.use((error, req, res, next) => {
  console.error(`[${req.id}] Unhandled error:`, error);
  res.status(500).json({
    error: 'Internal server error',
    request_id: req.id
  });
});

// Graceful shutdown handling
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('SIGINT received, shutting down gracefully');
  process.exit(0);
});

// Start server
const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(`Nimbus Analytics API Server running on port ${PORT}`);
  console.log(`Environment: ${NODE_ENV}`);
  console.log(`Process ID: ${process.pid}`);
  console.log(`Node.js version: ${process.version}`);
});

module.exports = app;
