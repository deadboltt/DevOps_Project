# =============================================================================
# Multi-Stage Production Dockerfile
# =============================================================================

# -----------------------------------------------------------------------------
# Stage 1: Build & Test Dependencies
# -----------------------------------------------------------------------------
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package manifests first for Docker layer caching
COPY package*.json ./

# Install ALL dependencies (including devDependencies for testing)
RUN npm ci

# Copy source code and test suite
COPY . .

# Run automated unit tests during container build
RUN npm test

# Prune devDependencies to keep only production packages
RUN npm prune --production

# -----------------------------------------------------------------------------
# Stage 2: Minimal Production Runtime
# -----------------------------------------------------------------------------
FROM node:20-alpine AS runner

# Set production environment
ENV NODE_ENV=production
ENV PORT=3000

WORKDIR /app

# Security Best Practice: Use pre-existing unprivileged 'node' user (UID 1000)
# Running as root inside containers is a critical security vulnerability
USER node

# Copy only production dependencies and source from builder stage
COPY --chown=node:node --from=builder /app/node_modules ./node_modules
COPY --chown=node:node --from=builder /app/src ./src
COPY --chown=node:node --from=builder /app/package.json ./package.json

# Expose microservice HTTP port
EXPOSE 3000

# Container Healthcheck (Docker-level liveness probe)
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/healthz || exit 1

# Start microservice
CMD ["node", "src/server.js"]
