#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORS_FILE="$ROOT/storage/cors.json"
BUCKET="gs://aifit-a7f6b.firebasestorage.app"

if ! command -v gsutil >/dev/null 2>&1; then
  echo "gsutil no está instalado. Instala Google Cloud SDK o ejecuta:"
  echo "  gcloud storage buckets update $BUCKET --cors-file=$CORS_FILE"
  exit 1
fi

echo "Aplicando CORS en $BUCKET ..."
gsutil cors set "$CORS_FILE" "$BUCKET"
gsutil cors get "$BUCKET"
echo "Listo."
