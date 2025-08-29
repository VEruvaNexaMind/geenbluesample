# Use Node.js 18 alpine image
FROM node:18-alpine

# Accept VERSION as build argument
ARG VERSION=blue
ENV VERSION=$VERSION

# Set working directory
WORKDIR /app

# Copy package files from the app directory
COPY app/package*.json ./

# Install dependencies
RUN npm install --omit=dev && npm cache clean --force

# Create non-root user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Copy application files from the app directory
COPY app/ .

# Overwrite index.html with the version-specific file
RUN cp /app/index-${VERSION}.html /app/index.html

# Change ownership to nodejs user
RUN chown -R nodejs:nodejs /app
USER nodejs

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

# Start the application
CMD ["npm", "start"]
