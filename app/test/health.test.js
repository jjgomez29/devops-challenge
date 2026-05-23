const request = require('supertest');
const app = require('../server');

describe('API Endpoints', () => {
  let server;

  beforeAll(() => {
    server = app.listen(0); // Random port for testing
  });

  afterAll((done) => {
    server.close(done);
  });

  describe('GET /health', () => {
    it('should return healthy status', async () => {
      const res = await request(app).get('/health');

      expect(res.statusCode).toBe(200);
      expect(res.body).toHaveProperty('status', 'healthy');
      expect(res.body).toHaveProperty('timestamp');
      expect(res.body).toHaveProperty('environment');
      expect(res.body).toHaveProperty('version');
    });
  });

  describe('GET /metrics', () => {
    it('should return metrics data', async () => {
      const res = await request(app).get('/metrics');

      expect(res.statusCode).toBe(200);
      expect(res.body).toHaveProperty('uptime_seconds');
      expect(res.body).toHaveProperty('memory');
      expect(res.body.memory).toHaveProperty('heap_used_mb');
      expect(res.body).toHaveProperty('nodejs_version');
    });
  });

  describe('GET /', () => {
    it('should return API info', async () => {
      const res = await request(app).get('/');

      expect(res.statusCode).toBe(200);
      expect(res.body).toHaveProperty('message');
      expect(res.body).toHaveProperty('endpoints');
      expect(res.body.endpoints).toHaveProperty('health');
      expect(res.body.endpoints).toHaveProperty('metrics');
    });
  });

  describe('GET /nonexistent', () => {
    it('should return 404 for unknown routes', async () => {
      const res = await request(app).get('/nonexistent');

      expect(res.statusCode).toBe(404);
      expect(res.body).toHaveProperty('error', 'Not Found');
    });
  });
});
