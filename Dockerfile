# Stage 1: build
FROM node:20-alpine AS builder
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
ARG VITE_API_VENTAS_URL
ARG VITE_API_DESPACHOS_URL
RUN npm run build

# Stage 2: serve
FROM nginx:alpine AS runner
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Permisos para usuario no-root
RUN mkdir -p /tmp/nginx/client_temp \
    && chown -R nginx:nginx /tmp/nginx \
    && chown -R nginx:nginx /usr/share/nginx/html \
    && chown -R nginx:nginx /var/cache/nginx \
    && chown -R nginx:nginx /var/log/nginx \
    && touch /run/nginx.pid \
    && chown nginx:nginx /run/nginx.pid

USER nginx
EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]
