#!/bin/bash

# Script to fix suspend/hibernate mode on ThinkPad T420
# Based on: docs/Linux Mint Suspend OR Wake Fix — ThinkPad T420.md
#
# This script disables USB wake sources (EHC1, EHC2) to prevent unwanted
# wake events from USB devices, wireless mice, keyboard, and touchpad.
# Only LID and SLPB (power button) will be able to wake the system.

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root"
   echo "Please run: sudo $0"
   exit 1
fi

print_info "Starting suspend/hibernate fix for ThinkPad T420..."
echo

# Step 1: Show current wakeup sources
print_info "Current ACPI wakeup sources:"
cat /proc/acpi/wakeup | grep enabled || true
echo

# Step 2: Create systemd service file
SERVICE_FILE="/etc/systemd/system/disable-usb-wake.service"
print_info "Creating systemd service at $SERVICE_FILE..."

cat > "$SERVICE_FILE" << 'EOF'
[Unit]
Description=Disable USB wake (ThinkPad T420)
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'for dev in EHC1 EHC2; do if grep -q "^$dev.*\*enabled" /proc/acpi/wakeup; then echo $dev > /proc/acpi/wakeup; fi; done'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

if [[ -f "$SERVICE_FILE" ]]; then
    print_success "Service file created successfully"
else
    print_error "Failed to create service file"
    exit 1
fi
echo

# Step 3: Reload systemd daemon
print_info "Reloading systemd daemon..."
systemctl daemon-reload
print_success "Systemd daemon reloaded"
echo

# Step 4: Enable the service
print_info "Enabling disable-usb-wake.service..."
systemctl enable disable-usb-wake.service
print_success "Service enabled (will run on boot)"
echo

# Step 5: Start the service immediately
print_info "Starting service now..."
systemctl start disable-usb-wake.service
print_success "Service started"
echo

# Step 6: Verify the fix
print_info "Verifying the fix..."
echo
echo "Enabled wakeup sources after fix:"
ENABLED_SOURCES=$(cat /proc/acpi/wakeup | grep enabled || true)
echo "$ENABLED_SOURCES"
echo

# Check if only LID and SLPB are enabled
LID_ENABLED=$(echo "$ENABLED_SOURCES" | grep -c "^LID" || true)
SLPB_ENABLED=$(echo "$ENABLED_SOURCES" | grep -c "^SLPB" || true)
OTHER_ENABLED=$(echo "$ENABLED_SOURCES" | grep -v "^LID" | grep -v "^SLPB" || true)

if [[ $LID_ENABLED -eq 1 ]] && [[ $SLPB_ENABLED -eq 1 ]] && [[ -z "$OTHER_ENABLED" ]]; then
    print_success "✓ Configuration is correct!"
    print_success "✓ Only LID and SLPB are enabled"
    echo
    print_info "Your system will now:"
    echo "  • Wake only from power button (SLPB)"
    echo "  • Respond to lid events (LID)"
    echo "  • Ignore USB devices, mouse, keyboard, and touchpad for wake"
    echo
    print_success "Fix applied successfully and will persist after reboot!"
elif [[ -z "$ENABLED_SOURCES" ]]; then
    print_warning "No enabled wakeup sources found. This might be expected on some systems."
    print_info "The service is installed and will apply the fix on reboot if needed."
else
    print_warning "Unexpected wakeup configuration detected"
    echo "Expected: Only LID and SLPB enabled"
    echo "Found: $ENABLED_SOURCES"
    echo
    print_info "The service is installed and may need a reboot to take full effect."
fi

echo
print_info "To verify after reboot, run:"
echo "  cat /proc/acpi/wakeup | grep enabled"
echo
print_info "To check service status, run:"
echo "  sudo systemctl status disable-usb-wake.service"
echo
print_info "To disable the fix (if needed), run:"
echo "  sudo systemctl disable --now disable-usb-wake.service"
echo

exit 0
