#!/bin/sh
set -e

# Render dış trafiği $PORT'a (varsayılan 10000) yönlendirir -> orada nginx dinler.
# API ise sadece konteyner içinde, 3001'de çalışır ve nginx üzerinden erişilir.
EXT_PORT="${PORT:-10000}"
API_PORT=3001

# Passkey'ler alan adına bağlıdır. Elle verilmediyse Render'ın verdiği
# onrender.com adresini kullan. Özel domain bağlarsan RP_ID ve ORIGIN'i env'de ayarla.
export RP_ID="${RP_ID:-$RENDER_EXTERNAL_HOSTNAME}"
export ORIGIN="${ORIGIN:-https://$RENDER_EXTERNAL_HOSTNAME}"

mkdir -p "${DATA_DIR:-/data}"

# nginx config'ini orijinal şablondan üret (yalnızca bu değişkenler yerine konur,
# nginx'in kendi $uri vb. değişkenlerine dokunulmaz).
NGINX_PORT="$EXT_PORT" BACKEND=127.0.0.1 PORT="$API_PORT" RESOLVER=127.0.0.1 \
  envsubst '${NGINX_PORT} ${BACKEND} ${PORT} ${RESOLVER} ${CF_CONNECTING_IP} ${BASE_PATH} ${MEDIA_UPLOAD_MAX}' \
  < /etc/nginx/opengym.conf.template > /etc/nginx/http.d/opengym.conf

# API'yi arka planda başlat
cd /app
PORT="$API_PORT" node server.js &
API_PID=$!

# İkisinden biri ölürse konteyner de dursun ki Render yeniden başlatsın
nginx -g 'daemon off;' &
NGINX_PID=$!

trap 'kill $API_PID $NGINX_PID 2>/dev/null' TERM INT
while kill -0 $API_PID 2>/dev/null && kill -0 $NGINX_PID 2>/dev/null; do sleep 5; done
echo "API veya nginx durdu, konteyner kapanıyor." >&2
kill $API_PID $NGINX_PID 2>/dev/null || true
exit 1
