TARGET = femto-bio
TOP = tt_ecp5_wrapper

OBJS += tt_wrapper.v ../src/*.v

all: ${TARGET}.bit

$(TARGET).ys: $(OBJS)
	yosys -p "synth_ecp5 -top ${TOP} -json $@" $(OBJS) > yosys.log
	@grep Warn yosys.log || true
	@grep Error yosys.log || true
	@egrep "[0-9]+ submodules" yosys.log | head -1
	@egrep "[0-9]+   TRELLIS_FF" yosys.log | awk '{sum+=$$1;}END{printf("%9d   TRELLIS_FF*\n", sum/2);}'
	@egrep "[0-9]+   LUT" yosys.log | head -1
	@echo	

$(TARGET)_out.config: $(TARGET).ys
	nextpnr-ecp5 --25k --package CABGA256 --speed 6 --json $< --textcfg $@ --lpf tt-ecp.lpf > nextpnr.log 2>& 1
	@grep Warn nextpnr.log || true
	@grep Error nextpnr.log || true
	@grep "Max frequency.*clk" nextpnr.log | tail -1
	@echo

$(TARGET).bit: $(TARGET)_out.config
	ecppack --svf ${TARGET}.svf $< $@

${TARGET}.svf: ${TARGET}.bit

prog: ${TARGET}.bit
	mpremote mount . + exec "import os; os.chdir('/'); import ecp_prog; ecp_prog.execute('/remote/$(TARGET).bit', 25000000)"

clean:
	rm -f *.svf *.bit *.config *.ys *.log

.PHONY: all prog clean
