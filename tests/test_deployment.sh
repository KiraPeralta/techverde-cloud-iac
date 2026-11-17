#!/bin/bash
set -e

WEBSITE_URL=$1
LOGS_BUCKET=$2

echo "=== Iniciando Pruebas Automatizadas de Despliegue y Seguridad ==="

# Prueba 1: Validar disponibilidad del portal web (RF-01)
echo "[TEST 1] Verificando respuesta HTTP 200 en: $WEBSITE_URL"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$WEBSITE_URL")

if [ "$HTTP_STATUS" -eq 200 ]; then
  echo "✅ EXITO: El portal web responde correctamente (HTTP 200 OK)."
else
  echo "❌ ERROR: Se esperaba HTTP 200 pero se recibio HTTP $HTTP_STATUS"
  exit 1
fi

# Prueba 2: Validar aislamiento y privacidad del bucket de auditoria en us-east-2 (ES-02)
LOGS_URL="https://${LOGS_BUCKET}.s3.us-east-2.amazonaws.com/"
echo "[TEST 2] Verificando bloqueo de acceso publico en bucket de logs: $LOGS_URL"
LOGS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$LOGS_URL")

if [ "$LOGS_STATUS" -eq 403 ]; then
  echo "✅ EXITO: El bucket de auditoria bloquea accesos no autorizados (HTTP 403 Forbidden)."
else
  echo "❌ ERROR: El bucket de logs devolvio HTTP $LOGS_STATUS (se esperaba 403)"
  exit 1
fi

echo "=== Todas las pruebas automatizadas finalizaron con exito ==="
