set top mlp_core
set rtl_files [list \
  rtl/src/mac_unit.sv \
  rtl/src/relu_unit.sv \
  rtl/src/controller.sv \
  rtl/src/weight_rom.sv \
  rtl/src/mlp_core.sv \
]

read_verilog -sv {*}$rtl_files
hierarchy -check -top $top

proc
opt
fsm
opt
memory
opt

if {[info exists ::env(SKY130_FD_SC_HD_LIBERTY)]} {
  set liberty $::env(SKY130_FD_SC_HD_LIBERTY)
  synth -top $top
  dfflibmap -liberty $liberty
  abc -liberty $liberty
  stat -liberty $liberty
  tee -o asic/timing.rpt stat -liberty $liberty
} else {
  synth -top $top
  stat
}

check
tee -o asic/area.rpt stat
write_json asic/mlp_core.json
write_verilog -noattr asic/mlp_core.netlist.v
