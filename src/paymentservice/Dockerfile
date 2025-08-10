# syntax=docker/dockerfile:1.7

# -------- deps / build stage
FROM --platform=$BUILDPLATFORM node:20.18.1-alpine AS builder

# Some packages need toolchain for postinstall scripts
RUN apk add --no-cache python3 make g++

WORKDIR /usr/src/app

# Copy only manifests first to maximize layer cache
COPY package*.json ./

# CI-friendly npm defaults
ENV CI=true \
    NPM_CONFIG_AUDIT=false \
    NPM_CONFIG_FUND=false \
    NPM_CONFIG_UPDATE_NOTIFIER=false \
    npm_config_loglevel=warn

# Use cache for npm and surface logs if something fails
# If you don't have a lockfile, it falls back to npm install
RUN --mount=type=cache,target=/root/.npm \
    /bin/sh -c '\
      if [ -f package-lock.json ]; then \
        npm ci --omit=dev --no-audit --no-fund || \
          { echo "=== NPM LOGS ==="; ls -l /root/.npm/_logs || true; cat /root/.npm/_logs/* || true; exit 1; }; \
      else \
        npm install --omit=dev --no-audit --no-fund || \
          { echo "=== NPM LOGS ==="; ls -l /root/.npm/_logs || true; cat /root/.npm/_logs/* || true; exit 1; }; \
      fi'

# -------- runtime stage
# Keep Alpine→Alpine to avoid ABI mismatches and keep it simple
FROM node:20.18.1-alpine

ENV NODE_ENV=production
WORKDIR /usr/src/app

# Copy production node_modules from builder
COPY --from=builder /usr/src/app/node_modules ./node_modules

# Then copy the app source
COPY . .

EXPOSE 50051
# Optional: add a healthcheck if you have one
# HEALTHCHECK CMD node healthcheck.js || exit 1

CMD ["node", "index.js"]
