const request = require('supertest');
const app = require('../src/server');

describe('Microservice API & Probe Endpoints', () => {
  // Test 1: Root Endpoint
  it('GET / should return 200 and application metadata', async () => {
    const res = await request(app).get('/');
    expect(res.statusCode).toEqual(200);
    expect(res.body).toHaveProperty('message');
    expect(res.body).toHaveProperty('version');
    expect(res.body).toHaveProperty('hostname');
  });

  // Test 2: Kubernetes Liveness Probe
  it('GET /healthz should return 200 and status healthy', async () => {
    const res = await request(app).get('/healthz');
    expect(res.statusCode).toEqual(200);
    expect(res.body.status).toEqual('healthy');
    expect(res.body).toHaveProperty('uptime_seconds');
  });

  // Test 3: Kubernetes Readiness Probe
  it('GET /ready should return 200 and status ready', async () => {
    const res = await request(app).get('/ready');
    expect(res.statusCode).toEqual(200);
    expect(res.body.status).toEqual('ready');
    expect(res.body.ready).toEqual(true);
  });

  // Test 4: Prometheus Metrics Scrape Endpoint
  it('GET /metrics should return 200 and Prometheus formatted text', async () => {
    const res = await request(app).get('/metrics');
    expect(res.statusCode).toEqual(200);
    expect(res.text).toContain('microservice_');
    expect(res.text).toContain('http_requests_total');
  });

  // Test 5: 404 handling
  it('GET /non-existent-route should return 404', async () => {
    const res = await request(app).get('/non-existent-route');
    expect(res.statusCode).toEqual(404);
  });
});
