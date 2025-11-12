#!/usr/bin/env bash
set -euo pipefail

# Variables (adjust as needed)
REPO="https://github.com/mnishimura1/zeus-orchestrator.git"
INSTALL_DIR="/opt/zeus"
ZEUS_USER="zeus"
SERVICE_NAME="zeus-orchestrator.service"
ENV_FILE="/etc/zeus-orchestrator.env"
PORT=8080

echo "🚀 Zeus Orchestrator - Systemd Service Deployment"
echo "=================================================="
echo ""

# Create system user and directories
echo "📦 Setting up user and directories..."
if ! id -u "${ZEUS_USER}" >/dev/null 2>&1; then
  sudo useradd --system --home "${INSTALL_DIR}" --shell /usr/sbin/nologin "${ZEUS_USER}"
  echo "✅ Created user: ${ZEUS_USER}"
else
  echo "✅ User ${ZEUS_USER} already exists"
fi

sudo mkdir -p "${INSTALL_DIR}"
sudo chown "${ZEUS_USER}:${ZEUS_USER}" "${INSTALL_DIR}"
echo "✅ Directories created"

# Clone or update repo
echo ""
echo "📥 Fetching repository..."
if [ -d "${INSTALL_DIR}/.git" ]; then
  sudo -u "${ZEUS_USER}" git -C "${INSTALL_DIR}" fetch --all --prune
  sudo -u "${ZEUS_USER}" git -C "${INSTALL_DIR}" reset --hard origin/main
  echo "✅ Repository updated"
else
  sudo -u "${ZEUS_USER}" git clone --depth 1 "${REPO}" "${INSTALL_DIR}"
  echo "✅ Repository cloned"
fi

# Build Rust binary
echo ""
echo "🔨 Building Rust binary..."
if command -v cargo >/dev/null 2>&1; then
  sudo -u "${ZEUS_USER}" bash -c "cd ${INSTALL_DIR} && cargo build --release"
  BINARY_PATH="${INSTALL_DIR}/target/release/zeus-orchestrator"
  echo "✅ Binary built: ${BINARY_PATH}"
else
  echo "⚠️  Cargo not found, attempting debug build..."
  sudo -u "${ZEUS_USER}" bash -c "cd ${INSTALL_DIR} && cargo build || true"
  BINARY_PATH="${INSTALL_DIR}/target/debug/zeus-orchestrator"
fi

# Verify binary exists
if [ ! -f "${BINARY_PATH}" ]; then
  echo "❌ Binary not found at: ${BINARY_PATH}"
  exit 1
fi

# Create env file
echo ""
echo "⚙️  Creating environment configuration..."
sudo tee "${ENV_FILE}" > /dev/null <<EOF
# Zeus Orchestrator Environment
ZEUS_HTTP_PORT=${PORT}
ZEUS_BIND_ADDR=0.0.0.0
LOG_LEVEL=info
RUST_LOG=info
RUST_BACKTRACE=1
# Add additional required keys here (e.g., ANTHROPIC_API_KEY)
EOF
sudo chown root:root "${ENV_FILE}"
sudo chmod 640 "${ENV_FILE}"
echo "✅ Environment file created: ${ENV_FILE}"

# Create systemd unit
echo ""
echo "🔧 Creating systemd service..."
sudo tee /etc/systemd/system/"${SERVICE_NAME}" > /dev/null <<'UNIT'
[Unit]
Description=Zeus Orchestrator
After=network.target
Wants=network-online.target

[Service]
Type=simple
EnvironmentFile=/etc/zeus-orchestrator.env
User=zeus
Group=zeus
WorkingDirectory=/opt/zeus
ExecStart=/opt/zeus/target/release/zeus-orchestrator
Restart=on-failure
RestartSec=3
LimitNOFILE=65536
SyslogIdentifier=zeus-orchestrator

# Security hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/zeus

[Install]
WantedBy=multi-user.target
UNIT

sudo systemctl daemon-reload
echo "✅ Systemd service created"

# Enable and start service
echo ""
echo "🚀 Starting service..."
sudo systemctl enable "${SERVICE_NAME}"
sudo systemctl restart "${SERVICE_NAME}"
echo "✅ Service enabled and started"

# Configure firewall
echo ""
echo "🔥 Configuring firewall..."
if command -v ufw >/dev/null 2>&1; then
  sudo ufw allow "${PORT}/tcp"
  sudo ufw reload || true
  echo "✅ UFW rule added for port ${PORT}"
elif command -v firewall-cmd >/dev/null 2>&1; then
  sudo firewall-cmd --permanent --add-port="${PORT}/tcp" || true
  sudo firewall-cmd --reload || true
  echo "✅ Firewalld rule added for port ${PORT}"
else
  echo "⚠️  No firewall detected (ufw/firewalld)"
fi

# Verification
echo ""
echo "=================================================="
echo "📊 Deployment Status"
echo "=================================================="
echo ""
echo "=== Service Status ==="
sudo systemctl status "${SERVICE_NAME}" --no-pager --lines=10 || true
echo ""
echo "=== Recent Logs (last 50 lines) ==="
sudo journalctl -u "${SERVICE_NAME}" -n 50 --no-pager || true
echo ""
echo "=================================================="
echo "✅ Deployment Complete"
echo "=================================================="
echo ""
echo "Service: ${SERVICE_NAME}"
echo "User: ${ZEUS_USER}"
echo "Location: ${INSTALL_DIR}"
echo "Port: ${PORT}"
echo "Environment: ${ENV_FILE}"
echo ""
echo "Management Commands:"
echo "  sudo systemctl status ${SERVICE_NAME}"
echo "  sudo systemctl restart ${SERVICE_NAME}"
echo "  sudo systemctl stop ${SERVICE_NAME}"
echo "  sudo journalctl -u ${SERVICE_NAME} -f"
echo ""
echo "⚠️  NOTE: Current Zeus code is minimal (hello world)."
echo "    Add actual HTTP server implementation before production use."
echo ""
