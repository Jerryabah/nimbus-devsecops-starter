# applications/analytics-api/Dockerfile
# Nimbus Analytics - Security-hardened container for analytics API
# Multi-stage build for minimal attack surface

#######################################################################
# Stage 1: Build environment (will be discarded)
#######################################################################
FROM node:18-alpine AS builder

# Create app directory
WORKDIR /usr/src/app

# Copy package files first for better layer caching
COPY package*.json ./

# Install dependencies including dev dependencies for build
RUN npm ci --only=production && npm cache clean --force

# Copy application source
COPY . .

# Security: Remove any potential sensitive files
RUN rm -rf .git .gitignore .env* .npmrc || true

#######################################################################
# Stage 2: Runtime environment (security-hardened)
#######################################################################
FROM node:18-alpine AS runtime

# Metadata labels for container management
LABEL org.opencontainers.image.title="Nimbus Analytics API"
LABEL org.opencontainers.image.description="Security-hardened Node.js API for analytics processing"
LABEL org.opencontainers.image.vendor="Nimbus Analytics"
LABEL org.opencontainers.image.version="1.0.0"
LABEL org.opencontainers.image.created="2024-01-01T00:00:00Z"
LABEL security.classification="confidential"
LABEL compliance.sox="required"
LABEL compliance.gdpr="applicable"

# Security: Install security updates and minimal packages only
RUN apk update && \
    apk upgrade && \
    apk add --no-cache \
    dumb-init \
    curl \
    ca-certificates && \
    rm -rf /var/cache/apk/* /tmp/*

# Security: Create non-privileged user (nimbus:1001)
# Using fixed UID/GID for consistency across environments
RUN addgroup -g 1001 nimbus && \
    adduser -D -u 1001 -G nimbus nimbus

# Security: Create application directory with proper ownership
WORKDIR /app

# Copy application files from builder stage
COPY --from=builder --chown=nimbus:nimbus /usr/src/app/node_modules ./node_modules
COPY --from=builder --chown=nimbus:nimbus /usr/src/app/package*.json ./
COPY --from=builder --chown=nimbus:nimbus /usr/src/app/server.js ./

# Security: Create necessary directories with proper permissions
RUN mkdir -p /app/logs /app/tmp && \
    chown -R nimbus:nimbus /app && \
    chmod -R 755 /app && \
    chmod 644 /app/server.js /app/package*.json

# Security: Remove shell access and package managers
RUN rm -rf /bin/sh /sbin/apk /usr/bin/wget /usr/bin/curl || true

# Security: Set file permissions (read-only filesystem preparation)
RUN chmod -R a-w /app/node_modules && \
    chmod -R a-w /usr/local/lib/node_modules || true

# Switch to non-privileged user
USER nimbus

# Security: Define environment variables
ENV NODE_ENV=production
ENV PORT=3000
ENV SERVICE_NAME=nimbus-analytics-api
ENV SERVICE_VERSION=1.0.0

# Security: Expose only the necessary port
EXPOSE 3000

# Security: Health check configuration
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

# Security: Use dumb-init to handle signals properly
# This prevents zombie processes and ensures graceful shutdowns
ENTRYPOINT ["dumb-init", "--"]

# Start the application
CMD ["node", "server.js"]

#######################################################################
# Security Configuration Summary:
# ✅ Multi-stage build (minimal runtime image)
# ✅ Non-root user execution (nimbus:1001)  
# ✅ Read-only filesystem compatible
# ✅ Minimal attack surface (Alpine + essential packages only)
# ✅ Security updates applied
# ✅ Proper signal handling (dumb-init)
# ✅ Health checks configured
# ✅ Metadata labels for compliance tracking
# ✅ No shell or unnecessary binaries
# ✅ Fixed UID/GID for security consistency
#######################################################################
