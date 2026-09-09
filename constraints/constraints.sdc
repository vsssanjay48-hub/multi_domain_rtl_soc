# ============================================================================
# Altera/Intel SDC Constraints for Multi-Domain RTL SoC
# ============================================================================
# For Quartus synthesis
# ============================================================================

# Clock definitions
create_clock -name clk_master0 -period 10.0 [get_ports clk_master0]
create_clock -name clk_master1 -period 12.0 [get_ports clk_master1]
create_clock -name clk_master2 -period 14.0 [get_ports clk_master2]
create_clock -name clk_master3 -period 16.0 [get_ports clk_master3]
create_clock -name clk_master4 -period 13.0 [get_ports clk_master4]

# ============================================================================
# ASYNC_REG Attributes (Altera QII attribute)
# ============================================================================
set_instance_assignment -name ASYNC_REG ON -to fifo_m0_to_m1|rd_gray_sync*
set_instance_assignment -name ASYNC_REG ON -to fifo_m0_to_m1|wr_gray_sync*
set_instance_assignment -name ASYNC_REG ON -to u_sync_uart_flag|sync*

# ============================================================================
# Disable timing between asynchronous clock domains
# ============================================================================
set_false_path -from clk_master0 -to clk_master1
set_false_path -from clk_master0 -to clk_master2
set_false_path -from clk_master0 -to clk_master3
set_false_path -from clk_master0 -to clk_master4
set_false_path -from clk_master1 -to clk_master0
set_false_path -from clk_master1 -to clk_master2
set_false_path -from clk_master1 -to clk_master3
set_false_path -from clk_master1 -to clk_master4
set_false_path -from clk_master2 -to [get_clocks *]
set_false_path -from clk_master3 -to [get_clocks *]
set_false_path -from clk_master4 -to [get_clocks *]

# ============================================================================
# CDC data path timing (relaxed)
# ============================================================================
set_max_delay -datapath_only 20 -from fifo_m0_to_m1|wr_ptr_gray -to fifo_m0_to_m1|rd_gray_sync*
set_max_delay -datapath_only 20 -from fifo_m0_to_m1|rd_ptr_gray -to fifo_m0_to_m1|wr_gray_sync*

echo "Altera SDC constraints loaded"
