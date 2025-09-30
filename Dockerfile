FROM node:18-alpine AS base

# Install dependencies only when needed
FROM base AS deps
# Check https://github.com/nodejs/docker-node/tree/b4117f9333da4138b03a546ec926ef50a31506c3#nodealpine to understand why libc6-compat might be needed.
# Install OpenSSL 3 for Prisma (Alpine 3.21 uses OpenSSL 3)
RUN apk add --no-cache libc6-compat openssl

WORKDIR /app

# Install dependencies based on the preferred package manager
COPY package.json package-lock.json* ./
COPY prisma ./prisma/

# Skip postinstall scripts to avoid husky and prisma issues
RUN npm ci --omit=dev --ignore-scripts

# Rebuild the source code only when needed
FROM base AS builder
WORKDIR /app

# Install OpenSSL 3 for Prisma in builder stage
RUN apk add --no-cache libc6-compat openssl

COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Set environment to skip husky
ENV HUSKY=0

# Install all dependencies (including dev) for build
RUN npm ci

# Generate Prisma client
RUN npx prisma generate

# Build the application
RUN npm run build

# Install sharp for image optimization in standalone mode
RUN npm install sharp

# Production image, copy all the files and run next
FROM base AS runner
WORKDIR /app

# Install OpenSSL 3 for Prisma in runner stage
RUN apk add --no-cache libc6-compat openssl

ENV NODE_ENV=production

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public

# Set the correct permission for prerender cache
RUN mkdir .next
RUN chown nextjs:nodejs .next

# Automatically leverage output traces to reduce image size
# https://nextjs.org/docs/advanced-features/output-file-tracing
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

# Copy Prisma files for runtime
COPY --from=builder --chown=nextjs:nodejs /app/node_modules/.prisma ./node_modules/.prisma
COPY --from=builder --chown=nextjs:nodejs /app/node_modules/@prisma ./node_modules/@prisma

# Copy sharp for image optimization
COPY --from=builder --chown=nextjs:nodejs /app/node_modules/sharp ./node_modules/sharp

USER nextjs

EXPOSE 3000

ENV PORT=3000

CMD ["node", "server.js"]
