# ============================================================================
# Xilinx XDC Constraints for Multi-Domain RTL SoC
# ============================================================================
# This file defines:
#   - Clock definitions (5 master + 5 generated clocks)
#   - Asynchronous clock groups
#   - CDC timing relaxation
#   - ASYNC_REG attribute enforcement
# ============================================================================

# ============================================================================
# Clock Definitions (5 independent master clocks)
# ============================================================================
create_clock -period 10.0 -name clk_master0 [get_ports clk_master0]
create_clock -period 12.0 -name clk_master1 [get_ports clk_master1]
create_clock -period 14.0 -name clk_master2 [get_ports clk_master2]
create_clock -period 16.0 -name clk_master3 [get_ports clk_master3]
create_clock -period 13.0 -name clk_master4 [get_ports clk_master4]

# Generated clocks from clock dividers
create_generated_clock -name clk_gen0 -source [get_ports clk_master0] -divide_by 2 [get_pins div_0/clk_out]
create_generated_clock -name clk_gen1 -source [get_ports clk_master1] -divide_by 3 [get_pins div_1/clk_out]
create_generated_clock -name clk_gen2 -source [get_ports clk_master2] -divide_by 4 [get_pins div_2/clk_out]
create_generated_clock -name clk_gen3 -source [get_ports clk_master3] -divide_by 5 [get_pins div_3/clk_out]
create_generated_clock -name clk_gen4 -source [get_ports clk_master4] -divide_by 2 [get_pins div_4/clk_out]

# ============================================================================
# Asynchronous Clock Groups
# Mark all master clocks as asynchronous to each other
# ============================================================================
set_clock_groups -asynchronous \
    -group {clk_master0 clk_gen0} \
    -group {clk_master1 clk_gen1} \
    -group {clk_master2 clk_gen2} \
    -group {clk_master3 clk_gen3} \
    -group {clk_master4 clk_gen4}

# ============================================================================
# CDC Synchronizer Timing (2-flop synchronizers)
# Allow extended delays for ASYNC_REG paths
# ============================================================================
# FIFO pointer synchronization (master0 -> master1)
set_max_delay 20.0 -datapath_only \
    -from [get_cells fifo_m0_to_m1/wr_ptr_gray] \
    -to [get_cells fifo_m0_to_m1/rd_gray_sync*]

set_max_delay 20.0 -datapath_only \
    -from [get_cells fifo_m0_to_m1/rd_ptr_gray] \
    -to [get_cells fifo_m0_to_m1/wr_gray_sync*]

# CDC handshake synchronizers (example: master0 interrupt flag)
set_max_delay 20.0 -datapath_only \
    -from [get_cells u_sync_uart_flag/sync*] \
    -to [get_ports *]

# ============================================================================
# False Paths (No timing analysis needed across CDC)
# ============================================================================
set_false_path -from [get_clocks clk_master0] -to [get_clocks clk_master1]
set_false_path -from [get_clocks clk_master1] -to [get_clocks clk_master0]
set_false_path -from [get_clocks clk_master0] -to [get_clocks clk_master2]
set_false_path -from [get_clocks clk_master2] -to [get_clocks clk_master0]
set_false_path -from [get_clocks clk_master0] -to [get_clocks clk_master3]
set_false_path -from [get_clocks clk_master3] -to [get_clocks clk_master0]
set_false_path -from [get_clocks clk_master0] -to [get_clocks clk_master4]
set_false_path -from [get_clocks clk_master4] -to [get_clocks clk_master0]
set_false_path -from [get_clocks clk_master1] -to [get_clocks clk_master2]
set_false_path -from [get_clocks clk_master2] -to [get_clocks clk_master1]

# ============================================================================
# ASYNC_REG Attributes (Xilinx synchronizer flip-flops)
# Forces synthesis tool to preserve register chains without optimization
# ============================================================================
set_property ASYNC_REG TRUE [get_cells fifo_m0_to_m1/rd_gray_sync*]
set_property ASYNC_REG TRUE [get_cells fifo_m0_to_m1/wr_gray_sync*]
set_property ASYNC_REG TRUE [get_cells u_sync_uart_flag/sync*]

# ============================================================================
# Reset Synchronization
# ============================================================================
set_false_path -from [get_ports global_rst_n] -to [get_clocks *]

# ============================================================================
# I/O Timing (UART, if timing-critical)
# ============================================================================
# Relax UART I/O timing (baud rates are much slower than clock domain)
set_output_delay -clock [get_clocks clk_master0] 2.0 [get_ports uart_tx*]
set_input_delay -clock [get_clocks clk_master*] 2.0 [get_ports uart_rx*]

# ============================================================================
# Multicycle Paths (optional, if CDC data not needed same cycle)
# ============================================================================
# Example: FIFO read data is only valid after 2-3 destination clock cycles
# set_multicycle_path 3 -setup -from [get_cells fifo_m0_to_m1/mem*] -to [get_ports rd_data]

echo "Constraints loaded successfully"
