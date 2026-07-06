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
app.use(express.json());

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
app.listen(PORT, "0.0.0.0", () => {
  console.log(`[DevSecOps App] Server running on port ${PORT}`);
  console.log(`[DevSecOps App] Environment: ${ENVIRONMENT}`);
  console.log(`[DevSecOps App] Version: ${APP_VERSION}`);
});

module.exports = app;
