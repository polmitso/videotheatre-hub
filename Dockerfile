# ==========================================
# STAGE 1: Αυτόματη βελτιστοποίηση εικόνων
# ==========================================
FROM alpine:3.19 AS optimizer
RUN apk add --no-cache imagemagick findutils

WORKDIR /src
COPY . .

# Αν υπάρχει φάκελος images, κάνει αυτόματο resize σε max 1920px και συμπίεση ποιότητας 82%
RUN if [ -d "images" ]; then \
      find images/ -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) -exec \
      magick "{}" -resize "1920x1920>" -strip -quality 82 "{}" \; ; \
    fi

# ==========================================
# STAGE 2: Nginx Production Web Server
# ==========================================
FROM nginx:alpine

# Προσθήκη custom ρυθμίσεων Nginx (Gzip, Cache, Security)
RUN rm /etc/nginx/conf.d/default.conf
COPY <<'EOF' /etc/nginx/conf.d/default.conf
server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    # Gzip Compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied expired no-cache no-store private auth;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml application/javascript;

    # Security Headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Browser Caching για Media & Assets
    location ~* \.(jpg|jpeg|png|gif|ico|webp|svg|mp4|webm|woff|woff2|ttf|css|js)$ {
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }

    # Fallback Routing
    location / {
        try_files $uri $uri/ /index.html;
    }

    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
        root /usr/share/nginx/html;
    }
}
EOF

# Αντιγραφή των βελτιστοποιημένων αρχείων
COPY --from=optimizer /src /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
