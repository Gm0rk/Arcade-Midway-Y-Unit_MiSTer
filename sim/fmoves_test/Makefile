# Finishing-move player test: rtl/yunit_fmoves.sv against the move programs
# and the fight situations of fm_check.py (the direct finishers' patch,
# the trigger taps, the combination of a set without sites).
#   make && python3 fm_check.py
# (fm_check.py --mutants also builds the player with deliberate faults and
# checks that the tests notice.)

RTL = ../../rtl

all: obj_dir/fm_tb

obj_dir/fm_tb: fm_tb.cpp $(RTL)/yunit_fmoves.sv $(RTL)/yunit_fmoves_tab.svh
	verilator --cc --exe --build -j 2 -O2 -Wno-fatal -Wno-WIDTH -Wno-lint --top-module yunit_fmoves \
		-I$(RTL) -o fm_tb $(RTL)/yunit_fmoves.sv fm_tb.cpp

clean:
	rm -rf obj_dir obj_mut
