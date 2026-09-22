#!/usr/bin/env bash
set -Eeuo pipefail

MODE="${1:-}"
ROOT="${TP2_ROOT:-}"
STATE_DIR="${TP2_STATE_DIR:-${ROOT}/var/lib/tp2-hardening}"
LOG_FILE="${TP2_LOG_FILE:-${ROOT}/var/log/tp2-hardening.log}"
APPLIED=0
SKIPPED=0
CHECKED=0
ERRORS=0

usage() {
  cat <<'USAGE'
Uso: sudo ./hardening.sh --check | --apply | --restore

Variables para pruebas aisladas:
  TP2_ROOT=/ruta/raiz-ficticia
  TP2_STATE_DIR=/ruta/estado
  TP2_LOG_FILE=/ruta/log
USAGE
}

if [[ "$MODE" != "--check" && "$MODE" != "--apply" && "$MODE" != "--restore" ]]; then
  usage
  exit 2
fi

if [[ -z "$ROOT" && ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "Error: para modificar el sistema real debe ejecutar el script con sudo." >&2
  exit 3
fi

path() { printf '%s%s' "$ROOT" "$1"; }

mkdir -p "$STATE_DIR" "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"
chmod 0600 "$LOG_FILE" 2>/dev/null || true

log() {
  local level="$1" control="$2" message="$3"
  printf '%s [%s] [%s] %s\n' "$(date -Iseconds)" "$level" "$control" "$message" | tee -a "$LOG_FILE"
}

mark_applied() { APPLIED=$((APPLIED + 1)); log "APPLIED" "$1" "$2"; }
mark_skipped() { SKIPPED=$((SKIPPED + 1)); log "SKIPPED" "$1" "$2"; }
mark_checked() { CHECKED=$((CHECKED + 1)); log "CHECK" "$1" "$2"; }
mark_error() { ERRORS=$((ERRORS + 1)); log "ERROR" "$1" "$2"; }

backup_key() { printf '%s' "$1" | sed 's#/#__#g'; }

backup_file() {
  local target="$1" real key
  real="$(path "$target")"
  key="$(backup_key "$target")"
  if [[ -e "$real" && ! -e "$STATE_DIR/$key.existed" ]]; then
    cp -a "$real" "$STATE_DIR/$key.backup"
    : > "$STATE_DIR/$key.existed"
  elif [[ ! -e "$real" && ! -e "$STATE_DIR/$key.absent" ]]; then
    : > "$STATE_DIR/$key.absent"
  fi
}

restore_file() {
  local target="$1" real key
  real="$(path "$target")"
  key="$(backup_key "$target")"
  if [[ -e "$STATE_DIR/$key.existed" ]]; then
    mkdir -p "$(dirname "$real")"
    cp -a "$STATE_DIR/$key.backup" "$real"
    mark_applied "RESTORE" "Restaurado $target"
  elif [[ -e "$STATE_DIR/$key.absent" ]]; then
    rm -f "$real"
    mark_applied "RESTORE" "Eliminado $target porque no existia antes del TP"
  else
    mark_skipped "RESTORE" "Sin respaldo registrado para $target"
  fi
}

write_file() {
  local target="$1" mode="$2" content="$3" real tmp
  real="$(path "$target")"
  mkdir -p "$(dirname "$real")"
  tmp="$(mktemp "$(dirname "$real")/.tp2.XXXXXX")"
  printf '%s' "$content" > "$tmp"
  chmod "$mode" "$tmp"
  mv "$tmp" "$real"
}

control_uid0() {
  local passwd_file
  passwd_file="$(path /etc/passwd)"
  if [[ ! -r "$passwd_file" ]]; then
    mark_error "UID0" "No se puede leer /etc/passwd"
    return
  fi
  local extra
  extra="$(awk -F: '$3 == 0 && $1 != "root" {print $1}' "$passwd_file" | paste -sd, -)"
  if [[ -n "$extra" ]]; then
    mark_error "UID0" "Cuentas adicionales con UID 0: $extra. No se corrigen automaticamente."
  else
    mark_checked "UID0" "Solo root posee UID 0"
  fi
}

# [[ -f "$real" ]] es un test condicional de bash que pregunta: ¿existe $real en el filesystem y es un archivo regular?
# Rama --check: solo lee /etc/ssh/sshd_config.d/99-tp2-hardening.conf si existe y compara contra PermitRootLogin no. No escribe nada, no llama sshd -t, no reinicia el servicio.
# grep -qx 'PermitRootLogin no' "$real" busca esa línea exacta dentro del archivo, pero sin imprimir nada — solo importa si la encontró o no (a través del código de salida).
control_ssh() {
  local target="/etc/ssh/sshd_config.d/99-tp2-hardening.conf"
  local content="PermitRootLogin no\n"
  real="$(path "$target")"

  if [[ "$MODE" == "--check" ]]; then
    if [[ ! -f "$real" ]]; then
      mark_error "SSH" "Archivo $target no existe"
      return
    fi

    if ! grep -qx 'PermitRootLogin no' "$real"; then
      mark_error "SSH" "Archivo $target existe pero no contiene PermitRootLogin no"
      return
    fi

    mark_checked "SSH" "Archivo $target existe y contiene PermitRootLogin no"
  elif [[ "$MODE" == "--apply" ]]; then
    if [[ -f "$real" ]] && grep -qx 'PermitRootLogin no' "$real"; then
      mark_skipped "SSH" "$target ya establece PermitRootLogin no"
      return
    fi

    backup_file "$target"
    write_file "$target" 0644 "$content"

    if ! sshd -t; then
      mark_error "SSH" "sshd -t fallo despues de modificar $target"
      return
    fi

    systemctl reload ssh
    mark_applied "SSH" "Creado/actualizado $target y ssh recargado"

  elif [[ "$MODE" == "--restore" ]]; then
    restore_file "$target"

    if ! sshd -t; then
      mark_error "SSH" "sshd -t fallo despues de restaurar $target"
      return
    fi

    systemctl reload ssh
    mark_applied "SSH" "Restaurado $target y ssh recargado"
  else
    mark_error "SSH" "Modo desconocido: $MODE"
    exit 4
  fi
}

control_pwquality() {
  local target="/etc/security/pwquality.conf.d/99-tp2-hardening.conf"
  local content="minlen = 12\nminclass = 3\nmaxrepeat = 3\n"
  local pam_file="/etc/pam.d/common-password"
  real="$(path "$target")"

  if [[ "$MODE" == "--check" ]]; then
    if ! grep -q 'pam_pwquality\.so' "$(path "$pam_file")" 2>/dev/null; then
      mark_error "PWQUALITY" "pam_pwquality no esta activo en $pam_file"
      return
    fi

    if [[ ! -f "$real" ]]; then
      mark_error "PWQUALITY" "Archivo $target no existe"
      return
    fi

    if ! grep -qx 'minlen = 12' "$real"; then
      mark_error "PWQUALITY" "Archivo $target existe pero no contiene la politica esperada"
      return
    fi

    mark_checked "PWQUALITY" "pam_pwquality activo y $target contiene la politica esperada"
  elif [[ "$MODE" == "--apply" ]]; then
    if ! grep -q 'pam_pwquality\.so' "$(path "$pam_file")" 2>/dev/null; then
      mark_error "PWQUALITY" "pam_pwquality no esta activo en $pam_file"
      return
    fi

    if [[ -f "$real" ]] && grep -qx 'minlen = 12' "$real"; then
      mark_skipped "PWQUALITY" "$target ya establece la politica esperada"
      return
    fi

    backup_file "$target"
    write_file "$target" 0644 "$content"

    mark_applied "PWQUALITY" "Creado/actualizado $target"

  elif [[ "$MODE" == "--restore" ]]; then
    restore_file "$target"
    mark_applied "PWQUALITY" "Restaurado $target"
  else
    mark_error "PWQUALITY" "Modo desconocido: $MODE"
    exit 4
  fi
}

control_umask() {
  local target="/etc/profile.d/99-tp2-hardening.sh"
  local content="umask 027\n"
  real="$(path "$target")"

  if [[ "$MODE" == "--check" ]]; then
    if [[ ! -f "$real" ]]; then
      mark_error "UMASK" "Archivo $target no existe"
      return
    fi

    if ! grep -qx 'umask 027' "$real"; then
      mark_error "UMASK" "Archivo $target existe pero no contiene umask 027"
      return
    fi

    mark_checked "UMASK" "Archivo $target existe y contiene umask 027"
  elif [[ "$MODE" == "--apply" ]]; then
    if [[ -f "$real" ]] && grep -qx 'umask 027' "$real"; then
      mark_skipped "UMASK" "$target ya establece umask 027"
      return
    fi

    backup_file "$target"
    write_file "$target" 0644 "$content"

    mark_applied "UMASK" "Creado/actualizado $target"
  elif [[ "$MODE" == "--restore" ]]; then
    restore_file "$target"
    mark_applied "UMASK" "Restaurado $target"
  else
    mark_error "UMASK" "Modo desconocido: $MODE"
    exit 4
  fi
}

control_sysctl() {
  local target="/etc/sysctl.d/99-tp2-hardening.conf"
  local content="fs.protected_hardlinks=1\nfs.protected_symlinks=1\n"
  real="$(path "$target")"

  if [[ "$MODE" == "--check" ]]; then
    if [[ ! -f "$real" ]]; then
      mark_error "SYSCTL" "Archivo $target no existe"
      return
    fi

    if ! grep -qx 'fs.protected_hardlinks=1' "$real" || ! grep -qx 'fs.protected_symlinks=1' "$real"; then
      mark_error "SYSCTL" "Archivo $target existe pero no fija ambos valores"
      return
    fi

    if [[ "$(sysctl -n fs.protected_hardlinks)" != "1" || "$(sysctl -n fs.protected_symlinks)" != "1" ]]; then
      mark_error "SYSCTL" "Valores efectivos del kernel no son 1"
      return
    fi

    mark_checked "SYSCTL" "Archivo $target correcto y valores efectivos del kernel en 1"
  elif [[ "$MODE" == "--apply" ]]; then
    if [[ -f "$real" ]] && grep -qx 'fs.protected_hardlinks=1' "$real" && grep -qx 'fs.protected_symlinks=1' "$real"; then
      mark_skipped "SYSCTL" "$target ya fija ambos valores"
      return
    fi

    backup_file "$target"
    write_file "$target" 0644 "$content"

    if ! sysctl -p "$real" >/dev/null; then
      mark_error "SYSCTL" "sysctl -p fallo al cargar $target"
      return
    fi

    mark_applied "SYSCTL" "Creado/actualizado $target y valores aplicados en caliente"
  elif [[ "$MODE" == "--restore" ]]; then
    restore_file "$target"

    if [[ -f "$real" ]]; then
      sysctl -p "$real" >/dev/null || true
    fi

    mark_applied "SYSCTL" "Restaurado $target"
  else
    mark_error "SYSCTL" "Modo desconocido: $MODE"
    exit 4
  fi
}

control_uid0
control_ssh
control_pwquality
control_umask
control_sysctl

log "RESUMEN" "TP2" "Aplicados=$APPLIED Omitidos=$SKIPPED Verificados=$CHECKED Errores=$ERRORS"

if (( ERRORS > 0 )); then
  exit 1
fi
