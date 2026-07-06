# ──────────────────────────────────────────────────────────────
# Stage 1: Build dependencies
# ──────────────────────────────────────────────────────────────
FROM node:22-alpine AS builder

WORKDIR /app

# Copy dependency manifests first for layer caching
COPY package.json package-lock.json* ./

# Install production dependencies only
RUN npm ci --only=production --ignore-scripts 2>/dev/null || npm install --only=production --ignore-scripts

# ──────────────────────────────────────────────────────────────
# Stage 2: Production image
# ──────────────────────────────────────────────────────────────
FROM node:22-alpine

# Security: Add metadata labels
LABEL maintainer="devsecops-team" \
      description="DevSecOps Demo Application" \
      version="1.0.0"

# Security: Create non-root user
RUN addgroup -g 10001 -S appgroup && \
    adduser -u 10001 -S appuser -G appgroup

WORKDIR /app

# Copy built dependencies from builder stage
COPY --from=builder --chown=appuser:appgroup /app/node_modules ./node_modules

# Copy application code
COPY --chown=appuser:appgroup server.js ./
COPY --chown=appuser:appgroup package.json ./

# Security: Drop to non-root user
USER appuser

# Expose application port
EXPOSE 3000

# Health check for container orchestrators
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD ["node", "-e", "require('http').get('http://localhost:3000/healthz', (r) => { process.exit(r.statusCode === 200 ? 0 : 1); }).on('error', () => process.exit(1))"]

# Start application
CMD ["node", "server.js"]
