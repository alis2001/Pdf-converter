# =====================================================
# PRODUCTION DOCKERFILE - FILE SERVICE
# Enterprise PDF Converter - Multi-stage Build
# =====================================================

# =====================================================
# STAGE 1: Dependencies Installation
# =====================================================
FROM node:18-alpine AS dependencies

# Set working directory
WORKDIR /app

# Create non-root user for security
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nodejs -u 1001

# Install production dependencies first (better caching)
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# =====================================================
# STAGE 2: Development Dependencies (for build tools)
# =====================================================
FROM node:18-alpine AS dev-deps

WORKDIR /app
COPY package*.json ./
RUN npm ci && npm cache clean --force

# =====================================================
# STAGE 3: Production Runtime
# =====================================================
FROM node:18-alpine AS production

# Set environment
ENV NODE_ENV=production
ENV PORT=3000

# Security: Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Install system dependencies for image processing and file handling
RUN apk add --no-cache \
    dumb-init \
    vips-dev \
    libc6-compat \
    && rm -rf /var/cache/apk/*

# Set working directory
WORKDIR /app

# Copy production dependencies from dependencies stage
COPY --from=dependencies --chown=nodejs:nodejs /app/node_modules ./node_modules

# Copy application code
COPY --chown=nodejs:nodejs . .

# Create necessary directories with proper permissions
RUN mkdir -p /app/logs && \
    mkdir -p /app/temp-uploads && \
    mkdir -p /app/uploads && \
    chown -R nodejs:nodejs /app/logs && \
    chown -R nodejs:nodejs /app/temp-uploads && \
    chown -R nodejs:nodejs /app/uploads

# Security: Remove package manager and build tools
RUN apk del --no-cache \
    && rm -rf /var/cache/apk/* \
    && rm -rf /tmp/*

# Switch to non-root user
USER nodejs

# Expose port
EXPOSE 3000

# Health check with proper error handling
HEALTHCHECK --interval=30s --timeout=10s --start-period=45s --retries=3 \
    CMD node -e " \
        const http = require('http'); \
        const options = { \
            host: 'localhost', \
            port: 3000, \
            path: '/health', \
            timeout: 5000 \
        }; \
        const req = http.request(options, (res) => { \
            if (res.statusCode === 200) { \
                process.exit(0); \
            } else { \
                console.log('Health check failed with status:', res.statusCode); \
                process.exit(1); \
            } \
        }); \
        req.on('timeout', () => { \
            console.log('Health check timeout'); \
            process.exit(1); \
        }); \
        req.on('error', (err) => { \
            console.log('Health check error:', err.message); \
            process.exit(1); \
        }); \
        req.setTimeout(5000); \
        req.end();"

# Labels for enterprise metadata
LABEL maintainer="PDF Converter Enterprise Team" \
      version="1.0.0" \
      description="File Management Service for Enterprise PDF Converter" \
      service="file-service" \
      tier="application" \
      component="microservice"

# Use dumb-init for proper signal handling in containers
ENTRYPOINT ["dumb-init", "--"]

# Start application
CMD ["node", "app.js"]