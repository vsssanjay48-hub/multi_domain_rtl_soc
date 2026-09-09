#!/bin/bash
# =============================================================================
# Simulation script for multi-domain RTL SoC
# Runs iverilog + VVP simulation
# =============================================================================

set -e

echo "========================================"
echo "  Multi-Domain RTL SoC Simulation"
echo "========================================"

VERILOG_COMPILER="iverilog"
VERILOG_RUNTIME="vvp"

# Directories
RTL_DIR="../rtl/verilog"
SIM_DIR="."

# Check if iverilog is installed
if ! command -v $VERILOG_COMPILER &> /dev/null; then
    echo "Error: iverilog not found. Install Icarus Verilog."
    exit 1
fi

echo "\n[1/3] Compiling top-level testbench..."
$VERILOG_COMPILER -o tb_soc \
    $RTL_DIR/soc_top.v \
    $RTL_DIR/clock_divider.v \
    $RTL_DIR/cdc_async_fifo.v \
    $RTL_DIR/cdc_synchronizer.v \
    $RTL_DIR/uart_core.v \
    $RTL_DIR/crc32_engine.v \
    $RTL_DIR/register_file.v \
    $RTL_DIR/arbiter.v \
    $RTL_DIR/priority_encoder.v \
    $SIM_DIR/tb_soc_top.v

echo "[2/3] Compiling FIFO testbench..."
$VERILOG_COMPILER -o tb_fifo \
    $RTL_DIR/cdc_async_fifo.v \
    $SIM_DIR/tb_cdc_async_fifo.v

echo "[3/3] Running simulations..."
echo ""
echo "\n>>> Running tb_soc_top (main testbench):"
$VERILOG_RUNTIME tb_soc 2>&1 | head -100

echo "\n>>> Running tb_cdc_async_fifo (FIFO-specific):"
$VERILOG_RUNTIME tb_fifo 2>&1 | head -50

echo "\n========================================"
echo "  Simulation Complete"
echo "========================================\n"
