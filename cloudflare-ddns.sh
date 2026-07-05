#!/usr/bin/env bash
# =============================================================================
# cloudflare-ddns — Atualiza registros DNS A (IPv4) e/ou AAAA (IPv6) via API
# da Cloudflare. Nada hardcoded: tudo via parâmetros.
#
# Uso:
#   cloudflare-ddns -h <hostname> -k <api_token> [-z <zone>] [-4] [-6] [-p] [-t <ttl>]
#
# Créditos: Aldemaro Campos (aldemaro.com.br) e Chico
# Licença: GPL v3
# =============================================================================
set -euo pipefail

# ── Funções ──────────────────────────────────────────────────────────────────

now() {
  date '+%Y-%m-%d %H:%M:%S'
}

log() {
  echo "[$(now)] $*"
}

err() {
  echo "[$(now)] [ERRO] $*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
cloudflare-ddns — Atualiza registros A (IPv4) e/ou AAAA (IPv6) na Cloudflare.

Uso:
  cloudflare-ddns -h <hostname> -k <api_token> [-z <zone>] [-4] [-6] [-p] [-t <ttl>]

Parâmetros obrigatórios:
  -h <hostname>    Nome completo do registro DNS (ex: meuservidor.seudominio.com)
  -k <api_token>   API Token da Cloudflare com permissão "DNS:Edit" na zona

Parâmetros opcionais:
  -z <zone>        Nome da zona/domínio (ex: seudominio.com). Se omitido, é
                    extraído automaticamente do hostname.
  -4               Atualiza o registro A (IPv4). Se omitido junto com -6,
                    detecta automaticamente os IPs disponíveis.
  -6               Atualiza o registro AAAA (IPv6). Se omitido junto com -4,
                    detecta automaticamente os IPs disponíveis.
  -p <bool>      Habilita (true) ou desabilita (false) o proxy Cloudflare
                    (laranjinha). Se omitido, o estado atual do registro não é
                    modificado.
  -t <ttl>         TTL em segundos. Padrão: 120 (Auto). Mínimo: 60.

  --help           Mostra esta ajuda e sai.

Exemplos:
  # Atualiza apenas IPv4
  cloudflare-ddns -h meuservidor.meudominio.com -k token123 -4

  # Atualiza apenas IPv6
  cloudflare-ddns -h meuservidor.meudominio.com -k token123 -6

  # Atualiza IPv4 e IPv6, com proxy ligado
  cloudflare-ddns -h meuservidor.meudominio.com -k token123 -4 -6 -p true

  # Atualiza IPv4 e IPv6, desligando o proxy
  cloudflare-ddns -h meuservidor.meudominio.com -k token123 -4 -6 -p false

  # Especifica zona explicitamente
  cloudflare-ddns -h sub.dominio.com.br -k token123 -z dominio.com.br -4 -6

Créditos: Aldemaro Campos (aldemaro.com.br) e Chico
EOF
  exit 0
}

# ── Parse dos parâmetros ────────────────────────────────────────────────────

HOSTNAME=""
API_TOKEN=""
ZONE=""
DO_A=false
DO_AAAA=false
PROXIED=""
TTL=120

# Se nenhum parâmetro foi passado, mostra ajuda
if [[ $# -eq 0 ]]; then
  usage
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h) HOSTNAME="$2"; shift 2 ;;
    -k) API_TOKEN="$2"; shift 2 ;;
    -z) ZONE="$2"; shift 2 ;;
    -4) DO_A=true; shift ;;
    -6) DO_AAAA=true; shift ;;
    -p) PROXIED="$2"; shift 2 ;;
    -t) TTL="$2"; shift 2 ;;
    --help) usage ;;
    *) err "Parâmetro desconhecido: $1. Use --help para ajuda." ;;
  esac
done

# ── Validações ───────────────────────────────────────────────────────────────

[[ -z "$HOSTNAME" ]] && err "Hostname obrigatório (-h). Use --help para ajuda."
[[ -z "$API_TOKEN" ]] && err "API Token obrigatório (-k). Use --help para ajuda."

# Se nem -4 nem -6 foram informados, detecta automaticamente
if [[ "$DO_A" == false && "$DO_AAAA" == false ]]; then
  log "Nenhum tipo de registro especificado. Detectando automaticamente..."
  IPV4_TEST=$(curl -4 -s --max-time 5 https://ifconfig.me 2>/dev/null || \
              curl -4 -s --max-time 5 https://icanhazip.com 2>/dev/null || true)
  IPV6_TEST=$(curl -6 -s --max-time 5 https://ifconfig.me 2>/dev/null || \
              curl -6 -s --max-time 5 https://icanhazip.com 2>/dev/null || true)
  if [[ -n "$IPV4_TEST" ]]; then
    DO_A=true
    log "IPv4 detectado: $IPV4_TEST"
  fi
  if [[ -n "$IPV6_TEST" ]]; then
    DO_AAAA=true
    log "IPv6 detectado: $IPV6_TEST"
  fi
  if [[ "$DO_A" == false && "$DO_AAAA" == false ]]; then
    err "Não foi possível detectar IPv4 nem IPv6. Especifique -4 e/ou -6 manualmente."
  fi
fi

[[ "$TTL" -lt 60 ]] && TTL=60

# Valida -p se informado
if [[ -n "$PROXIED" ]]; then
  [[ "$PROXIED" != "true" && "$PROXIED" != "false" ]] && err "Valor inválido para -p: '$PROXIED'. Use 'true' ou 'false'."
fi

# Extrai a zona do hostname se não foi fornecida
if [[ -z "$ZONE" ]]; then
  ZONE="${HOSTNAME#*.}"
fi

# ── Obtém IPs públicos ──────────────────────────────────────────────────────

IPV4=""
IPV6=""

if [[ "$DO_A" == true ]]; then
  IPV4=$(curl -4 -s --max-time 10 https://ifconfig.me 2>/dev/null || \
          curl -4 -s --max-time 10 https://icanhazip.com 2>/dev/null || \
          curl -4 -s --max-time 10 https://api.ipify.org 2>/dev/null || true)
  [[ -z "$IPV4" ]] && err "Não foi possível obter o IPv4 público."
  log "IPv4 público: $IPV4"
fi

if [[ "$DO_AAAA" == true ]]; then
  IPV6=$(curl -6 -s --max-time 10 https://ifconfig.me 2>/dev/null || \
          curl -6 -s --max-time 10 https://icanhazip.com 2>/dev/null || \
          curl -6 -s --max-time 10 https://api6.ipify.org 2>/dev/null || true)
  [[ -z "$IPV6" ]] && err "Não foi possível obter o IPv6 público."
  log "IPv6 público: $IPV6"
fi

# ── Obtém Zone ID ────────────────────────────────────────────────────────────

log "Obtendo Zone ID para: $ZONE"

ZONE_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$ZONE" \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json")

ZONE_ID=$(echo "$ZONE_RESPONSE" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    if d.get('result'):
        print(d['result'][0]['id'])
except Exception:
    pass
")

[[ -z "$ZONE_ID" ]] && err "Zone ID não encontrado para '$ZONE'. Verifique o nome da zona e a API Token."
log "Zone ID: $ZONE_ID"

# ── Função de atualização ────────────────────────────────────────────────────

update_record() {
  local record_type="$1"
  local ip="$2"

  log "Buscando registro $record_type existente para $HOSTNAME..."

  RECORD_JSON=$(curl -s -X GET \
    "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=$record_type&name=$HOSTNAME" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "Content-Type: application/json")

  RECORD_ID=$(echo "$RECORD_JSON" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    if d.get('result'):
        print(d['result'][0]['id'])
except Exception:
    pass
")

  CURRENT_IP=$(echo "$RECORD_JSON" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    if d.get('result'):
        print(d['result'][0]['content'])
except Exception:
    pass
")

  CURRENT_PROXIED=$(echo "$RECORD_JSON" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    if d.get('result'):
        print(d['result'][0].get('proxied', ''))
except Exception:
    pass
")

  if [[ -n "$CURRENT_IP" && "$CURRENT_IP" == "$ip" ]]; then
    log "[OK] $HOSTNAME $record_type já está em $ip — nada a fazer."
    return 0
  fi

  # Monta o payload JSON com Python (evita problemas de true/false case)
  # Se -p foi informado, usa o valor passado. Senão, mantém o proxied atual do registro.
  local payload proxied_val
  if [[ -n "$PROXIED" ]]; then
    proxied_val="$([ "$PROXIED" = true ] && echo "True" || echo "False")"
  elif [[ -n "$CURRENT_PROXIED" ]]; then
    proxied_val="$([ "$CURRENT_PROXIED" = True ] && echo "True" || echo "False")"
  else
    proxied_val=""
  fi

  if [[ -n "$proxied_val" ]]; then
    payload=$(python3 -c "
import json
d = {
    'type': '$record_type',
    'name': '$HOSTNAME',
    'content': '$ip',
    'ttl': $TTL,
    'proxied': $proxied_val
}
print(json.dumps(d))
")
  else
    payload=$(python3 -c "
import json
d = {
    'type': '$record_type',
    'name': '$HOSTNAME',
    'content': '$ip',
    'ttl': $TTL
}
print(json.dumps(d))
")
  fi

  if [[ -n "$RECORD_ID" ]]; then
    log "Atualizando registro $record_type (ID: $RECORD_ID)..."
    RESULT=$(curl -s -X PUT \
      "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
      -H "Authorization: Bearer $API_TOKEN" \
      -H "Content-Type: application/json" \
      -d "$payload")
  else
    log "Criando novo registro $record_type..."
    RESULT=$(curl -s -X POST \
      "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
      -H "Authorization: Bearer $API_TOKEN" \
      -H "Content-Type: application/json" \
      -d "$payload")
  fi

  SUCCESS=$(echo "$RESULT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('success', False))
except Exception:
    print('False')
")

  if [[ "$SUCCESS" == "True" ]]; then
    log "[OK] $HOSTNAME $record_type → $ip"
  else
    local err_msg
    err_msg=$(echo "$RESULT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(json.dumps(d.get('errors', [])))
except Exception:
    print('desconhecido')
")
    log "[FALHA] Falha ao atualizar $record_type: $err_msg"
    return 1
  fi
}

# ── Executa ──────────────────────────────────────────────────────────────────

EXIT_CODE=0

if [[ "$DO_A" == true ]]; then
  update_record "A" "$IPV4" || EXIT_CODE=1
fi

if [[ "$DO_AAAA" == true ]]; then
  update_record "AAAA" "$IPV6" || EXIT_CODE=1
fi

exit "$EXIT_CODE"
