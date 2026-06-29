# =============================================================================
# build.tcl -- batch build profiles for the miniB210 LibreSDR FPGA.
#
# Produces a bitstream for any (clock-variant x device) combination without
# touching the GUI. The two orthogonal knobs:
#
#   clock variant : which ball carries the 40MHz TCXO (the only PCB difference)
#                     w19 -> 20260530 board            (clk_w19.xdc)
#                     v18 -> all 202604xx boards (0402/0407)  (clk_v18.xdc)
#   device        : which Artix-7 is populated
#                     100t -> xc7a100tfgg484-2
#                     200t -> xc7a200tfbg484-2   (484-ball footprint-compatible)
#
# Usage (from anywhere):
#   vivado -mode batch -source fpga/build.tcl -tclargs <clk> <dev> [jobs]
# Examples:
#   vivado -mode batch -source fpga/build.tcl -tclargs w19 100t
#   vivado -mode batch -source fpga/build.tcl -tclargs v18 200t 12
#
# Output:  fpga/build/libresdr_b210_<clk>_<dev>.bit  and  .bin
# =============================================================================

# ---- args -------------------------------------------------------------------
set clk  [expr {[llength $argv] > 0 ? [lindex $argv 0] : "w19"}]
set dev  [expr {[llength $argv] > 1 ? [lindex $argv 1] : "100t"}]
set jobs [expr {[llength $argv] > 2 ? [lindex $argv 2] : 8}]

set clk [string tolower $clk]
set dev [string tolower $dev]

if {$clk ni {w19 v18}} { error "clk must be 'w19' or 'v18' (got '$clk')" }

switch -- $dev {
    100t { set part "xc7a100tfgg484-2" }
    200t { set part "xc7a200tfbg484-2" }
    default { error "dev must be '100t' or '200t' (got '$dev')" }
}

# ---- locate project (paths relative to this script) -------------------------
set here     [file dirname [file normalize [info script]]]
set proj     [file join $here libresdr_b210 libresdr_b210.xpr]
set xdc_dir  [file join $here libresdr_b210 libresdr_b210.srcs constrs_2 imports xdc]
set out_dir  [file join $here build]
file mkdir $out_dir

if {![file exists $proj]} { error "project not found: $proj" }

puts "============================================================"
puts " build profile : clk=$clk  dev=$dev  part=$part  jobs=$jobs"
puts " project       : $proj"
puts " output        : [file join $out_dir libresdr_b210_${clk}_${dev}.bin]"
puts "============================================================"

open_project $proj

# ---- ensure both clock xdc files are in the constraint set (idempotent) -----
foreach v {w19 v18} {
    set f [file join $xdc_dir clk_${v}.xdc]
    if {[llength [get_files -quiet clk_${v}.xdc]] == 0} {
        puts "adding constraint file: clk_${v}.xdc"
        add_files -fileset constrs_2 $f
    }
}

# ---- select exactly one clock variant ---------------------------------------
set_property is_enabled false [get_files clk_w19.xdc]
set_property is_enabled false [get_files clk_v18.xdc]
set_property is_enabled true  [get_files clk_${clk}.xdc]
puts "enabled clock constraint: clk_${clk}.xdc"

# ---- set device, then reconcile EVERY IP to that part -----------------------
# 关键点：工程 part 与「IP 定制时记录的 part」必须一致，否则 IP 被 locked，
# OOC 综合不会启动，顶层 synth 报 "module 'xxx' not found"。
# 只比较工程 part 是不够的——上一次构建可能把 IP 定到了另一个器件，而工程 part
# 看起来没变。所以这里每次都：① 设工程 part；② 找出锁定的 IP（多为 part 不符
# 或 clean 删过 .gen）→ upgrade_ip 解锁并按当前 part 重定制 → 复位其失败的 OOC
# run；③ 对所有 IP 生成输出产物（已最新者 Vivado 自动跳过，不浪费时间）。
set cur_part [get_property part [current_project]]
puts "project part: $cur_part -> $part"
set_property part $part [current_project]

set ips [get_ips -quiet]
if {[llength $ips] > 0} {
    set locked {}
    foreach ip $ips {
        if {[get_property IS_LOCKED $ip]} { lappend locked $ip }
    }
    if {[llength $locked] > 0} {
        puts "re-targeting locked IP(s) to $part: $locked"
        upgrade_ip -quiet $locked
        foreach ip $locked {
            set r [get_runs -quiet ${ip}_synth_1]
            if {[llength $r] > 0} { reset_run $r }
        }
    }
    puts "generating IP output products ([llength $ips] IP) ..."
    generate_target -quiet all [get_ips -quiet]
}

# ---- synth -> impl -> bitstream ---------------------------------------------
reset_run synth_1
launch_runs synth_1 -jobs $jobs
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
    error "synthesis failed -- see [get_property DIRECTORY [get_runs synth_1]]"
}

launch_runs impl_1 -to_step write_bitstream -jobs $jobs
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
    error "implementation/bitstream failed -- see [get_property DIRECTORY [get_runs impl_1]]"
}

# ---- emit cleanly-named .bit + .bin -----------------------------------------
set out [file join $out_dir libresdr_b210_${clk}_${dev}]
open_run impl_1
write_bitstream -force -bin_file ${out}.bit

puts "============================================================"
puts " DONE.  wrote:"
puts "   ${out}.bit"
puts "   ${out}.bin   <- load with  --args=\"type=b200,fpga=${out}.bin\""
puts "============================================================"
close_project
