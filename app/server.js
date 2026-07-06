"use strict";

const express = require("express");
const os = require("os");

// ──────────────────────────────────────────────
// Application Configuration
// ──────────────────────────────────────────────
const PORT = process.env.PORT || 3000;
const APP_VERSION = process.env.APP_VERSION || "1.0.0";
const ENVIRONMENT = process.env.NODE_ENV || "development";

const app = express();

// ── Security: Disable X-Powered-By header to prevent tech stack disclosure ──
app.disable("x-powered-by");

// ── Security: Enforce Security Headers manually to avoid extra dependencies ──
app.use((req, res, next) => {
  res.setHeader("X-Content-Type-Options", "nosniff");
  res.setHeader("X-Frame-Options", "DENY");
  res.setHeader("X-XSS-Protection", "1; mode=block");
  res.setHeader("Content-Security-Policy", "default-src 'self'");
  res.setHeader("Strict-Transport-Security", "max-age=31536000; includeSubDomains");
  res.setHeader("Referrer-Policy", "no-referrer");
  next();
});

// ── Security: Lightweight In-Memory Rate Limiting (mitigate DoS without adding dependencies) ──
const rateLimitWindow = 60000; // 1 minute
const rateLimitMax = 100; // 100 requests per minute
const rateLimit = new Map();

app.use((req, res, next) => {
  const ip = req.ip || req.headers["x-forwarded-for"] || req.socket.remoteAddress;
  const now = Date.now();

  if (!rateLimit.has(ip)) {
    rateLimit.set(ip, []);
  }

  const timestamps = rateLimit.get(ip).filter(t => now - t < rateLimitWindow);
  if (timestamps.length >= rateLimitMax) {
    return res.status(429).json({
      error: "Too Many Requests",
      message: "Rate limit exceeded. Please try again in a minute."
    });
  }

  timestamps.push(now);
  rateLimit.set(ip, timestamps);
  next();
});

app.use(express.json());

// ── Periodic cleanup of rate limit map to prevent memory leaks ──
setInterval(() => {
  const now = Date.now();
  for (const [ip, timestamps] of rateLimit.entries()) {
    const active = timestamps.filter(t => now - t < rateLimitWindow);
    if (active.length === 0) {
      rateLimit.delete(ip);
    } else {
      rateLimit.set(ip, active);
    }
  }
}, 300000); // Clean up every 5 minutes

// ──────────────────────────────────────────────
// Health & Readiness Endpoints
// ──────────────────────────────────────────────

/**
 * Liveness probe — Kubernetes uses this to know the container is alive.
 */
app.get("/healthz", (_req, res) => {
  res.status(200).json({
    status: "healthy",
    timestamp: new Date().toISOString(),
  });
});

/**
 * Readiness probe — Kubernetes uses this to know the container can serve traffic.
 */
app.get("/readyz", (_req, res) => {
  res.status(200).json({
    status: "ready",
    timestamp: new Date().toISOString(),
  });
});

// ──────────────────────────────────────────────
// Application Endpoints
// ──────────────────────────────────────────────

/**
 * Root endpoint — returns application metadata.
 */
app.get("/", (_req, res) => {
  res.status(200).json({
    application: "DevSecOps Demo Application",
    version: APP_VERSION,
    environment: ENVIRONMENT,
    hostname: os.hostname(),
    message: "Welcome to the Secure CI/CD Pipeline demo!",
    security: {
      pipeline: "Hadolint → Trivy → Checkov → OPA → Deploy",
      runtime: "Falco",
    },
  });
});

/**
 * /info — returns system and runtime information.
 */
app.get("/info", (_req, res) => {
  res.status(200).json({
    runtime: {
      nodeVersion: process.version,
      platform: os.platform(),
      arch: os.arch(),
      uptime: `${Math.floor(process.uptime())}s`,
      memoryUsage: process.memoryUsage(),
    },
    host: {
      hostname: os.hostname(),
      cpus: os.cpus().length,
      totalMemory: `${Math.round(os.totalmem() / 1024 / 1024)}MB`,
      freeMemory: `${Math.round(os.freemem() / 1024 / 1024)}MB`,
    },
  });
});

/**
 * /security — returns the security posture summary.
 */
app.get("/security", (_req, res) => {
  res.status(200).json({
    securityGates: [
      { gate: "Hadolint", type: "Static Analysis", target: "Dockerfile", status: "enforced" },
      { gate: "Trivy", type: "Vulnerability Scan", target: "Container Image", status: "enforced" },
      { gate: "Checkov", type: "IaC Scan", target: "Kubernetes Manifests", status: "enforced" },
      { gate: "OPA/Conftest", type: "Policy Enforcement", target: "Kubernetes Manifests", status: "enforced" },
      { gate: "Falco", type: "Runtime Monitoring", target: "Running Containers", status: "active" },
    ],
    policies: [
      "Registry restriction (trusted-registry.company.com only)",
      "Resource limits enforcement (CPU & Memory)",
      "Mandatory cost-center label",
    ],
  });
});

// ──────────────────────────────────────────────
// Start Server
// ──────────────────────────────────────────────
const server = app.listen(PORT, "0.0.0.0", () => {
  console.log(`[DevSecOps App] Server running on port ${PORT}`);
  console.log(`[DevSecOps App] Environment: ${ENVIRONMENT}`);
  console.log(`[DevSecOps App] Version: ${APP_VERSION}`);
});

// ── Security & Operations: Graceful Shutdown handling ──
const gracefulShutdown = (signal) => {
  console.log(`[DevSecOps App] Received ${signal}. Shutting down gracefully...`);
  server.close(() => {
    console.log("[DevSecOps App] HTTP server closed.");
    process.exit(0);
  });

  // Force shutdown if connections do not close within 10s
  setTimeout(() => {
    console.error("[DevSecOps App] Could not close connections in time, forcefully shutting down");
    process.exit(1);
  }, 10000);
};

process.on("SIGTERM", () => gracefulShutdown("SIGTERM"));
process.on("SIGINT", () => gracefulShutdown("SIGINT"));

module.exports = app;
