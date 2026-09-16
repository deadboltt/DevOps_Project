const express = require('express');
const client = require('prom-client');
const os = require('os');

const app = express();
const PORT = process.env.PORT || 3000;
const APP_VERSION = process.env.APP_VERSION || '1.0.0';
const ENVIRONMENT = process.env.ENVIRONMENT || 'development';

// -----------------------------------------------------------------------------
// Prometheus Metrics Configuration
// -----------------------------------------------------------------------------
// Collect default Node.js and OS metrics (heap, memory, CPU, event loop lag)
const collectDefaultMetrics = client.collectDefaultMetrics;
collectDefaultMetrics({ prefix: 'microservice_' });

// Custom Prometheus Counter: Track total HTTP requests by method, route, and status
const httpRequestCounter = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests received',
  labelNames: ['method', 'route', 'status_code'],
});

// Custom Prometheus Histogram: Track HTTP request latency/duration
const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5],
});

// Middleware: Intercept every request to record Prometheus latency and counters
app.use((req, res, next) => {
  const start = process.hrtime();

  res.on('finish', () => {
    const diff = process.hrtime(start);
    const durationInSeconds = diff[0] + diff[1] / 1e9;
    const route = req.route ? req.route.path : req.path;

    httpRequestCounter.inc({
      method: req.method,
      route: route,
      status_code: res.statusCode,
    });

    httpRequestDuration.observe(
      {
        method: req.method,
        route: route,
        status_code: res.statusCode,
      },
      durationInSeconds
    );
  });

  next();
});

// -----------------------------------------------------------------------------
// Application Routes
// -----------------------------------------------------------------------------

// 1. Root Endpoint: Application information & Pod identification
app.get('/', (req, res) => {
  res.status(200).json({
    message: 'Hello from Full GitOps EKS Platform!',
    version: APP_VERSION,
    environment: ENVIRONMENT,
    hostname: os.hostname(),
    timestamp: new Date().toISOString(),
  });
});

// 2. Kubernetes Liveness Probe: Checks if the application process is alive
// If this fails (e.g. infinite loop/deadlock), Kubernetes kubelet restarts the pod
app.get('/healthz', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    uptime_seconds: Math.floor(process.uptime()),
    timestamp: new Date().toISOString(),
  });
});

// 3. Kubernetes Readiness Probe: Checks if the application is ready to accept traffic
// If this fails (e.g. database not connected), Kubernetes removes the pod from Endpoints
app.get('/ready', (req, res) => {
  // In production, you would check database connectivity or external dependencies here
  res.status(200).json({
    status: 'ready',
    ready: true,
    timestamp: new Date().toISOString(),
  });
});

// 4. Prometheus Metrics Scrape Endpoint: Scraped periodically by Prometheus Server
app.get('/metrics', async (req, res) => {
  try {
    res.set('Content-Type', client.register.contentType);
    res.end(await client.register.metrics());
  } catch (err) {
    res.status(500).end(err.message);
  }
});

// -----------------------------------------------------------------------------
// Server Start & Graceful Shutdown
// -----------------------------------------------------------------------------
let server;
if (process.env.NODE_ENV !== 'test') {
  server = app.listen(PORT, () => {
    console.log(`[✓] Microservice running on port ${PORT}`);
    console.log(`[✓] Health: http://localhost:${PORT}/healthz`);
    console.log(`[✓] Ready:  http://localhost:${PORT}/ready`);
    console.log(`[✓] Metrics: http://localhost:${PORT}/metrics`);
  });

  // Graceful shutdown handling: Handles Kubernetes SIGTERM signal during rolling updates
  const gracefulShutdown = (signal) => {
    console.log(`Received ${signal}. Shutting down gracefully...`);
    server.close(() => {
      console.log('HTTP server closed cleanly. Exiting.');
      process.exit(0);
    });

    // Force shutdown after 10 seconds if connections refuse to drain
    setTimeout(() => {
      console.error('Forcefully terminating server.');
      process.exit(1);
    }, 10000);
  };

  process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
  process.on('SIGINT', () => gracefulShutdown('SIGINT'));
}

module.exports = app;
