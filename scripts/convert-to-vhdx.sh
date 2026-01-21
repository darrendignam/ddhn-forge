#!/bin/bash
# Convert QCOW2 to VHDX for Windows ARM Hyper-V
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}ViPER ARM64 QCOW2 to VHDX Converter${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Default paths
INPUT_DIR="output-qemu-arm64"
QCOW2_FILE="${INPUT_DIR}/viper-v1.2-alpha-arm64.qcow2"
VHDX_FILE="${INPUT_DIR}/viper-v1.2-alpha-arm64.vhdx"

# Check if QCOW2 file exists
if [ ! -f "$QCOW2_FILE" ]; then
    echo -e "${RED}Error: QCOW2 file not found: $QCOW2_FILE${NC}"
    echo "Please ensure the ARM64 build has completed successfully."
    exit 1
fi

echo -e "${GREEN}✓${NC} Found QCOW2 file: $QCOW2_FILE"

# Get QCOW2 file info
echo ""
echo "QCOW2 file information:"
qemu-img info "$QCOW2_FILE"
echo ""

# Convert to VHDX
echo -e "${BLUE}Converting to VHDX format...${NC}"
qemu-img convert -f qcow2 -O vhdx "$QCOW2_FILE" "$VHDX_FILE"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Conversion successful!"
    echo ""
    echo "VHDX file information:"
    qemu-img info "$VHDX_FILE"
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Conversion Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "Output file: $VHDX_FILE"
    echo ""
    echo "This VHDX file can be used with:"
    echo "  • Windows ARM Hyper-V"
    echo "  • Windows ARM VMware (if supported)"
    echo ""
    echo "To use in Hyper-V:"
    echo "  1. Open Hyper-V Manager"
    echo "  2. Create a new Virtual Machine"
    echo "  3. Select 'Use an existing virtual hard disk'"
    echo "  4. Browse to: $VHDX_FILE"
    echo "  5. Ensure VM Generation is set to 2 (UEFI)"
    echo ""
else
    echo -e "${RED}Error: Conversion failed${NC}"
    exit 1
fi
