//============================================================================
//  yunit_opposite - opposite directions held together: the last press wins
//
//  A cabinet stick cannot hold Up with Down or Left with Right, so the games
//  never expect it. A pad, a keyboard or a button mapped to a direction can,
//  and Smash T.V. does not survive it. This filter sits between the controls
//  and the game's input ports. For each axis, while both directions are held
//  only the one pressed last reaches the game; releasing it hands control
//  back to the one still held. If both go down in the same clock the axis
//  reads neutral until one is let go. A lone direction passes through
//  unchanged.
//
//  "in" is two axes, {A1, B1, A0, B0} in pairs: [3:2] one axis and [1:0] the
//  other, so the joystick's {Up, Down, Left, Right} and the fire sticks'
//  order both fit.
//
//  Copyright (C) 2026 Gm0rk - GPL-3.0-or-later
//============================================================================

module yunit_opposite
(
	input        clk,
	input  [3:0] in,
	output [3:0] out
);

reg  [3:0] prev = 4'b0000;  // "in" one clock ago, to find new presses
reg  [3:0] win  = 4'b0000;  // per direction: pressed last while its opposite is held
reg  [3:0] win_n;
reg  [3:0] res;

wire [3:0] fresh = in & ~prev;  // pressed this clock

integer k;
always @(*) begin
	win_n = 4'b0000;
	res   = 4'b0000;
	for (k = 0; k < 4; k = k + 2) begin
		// pair (k+1, k) held together: a direction wins if it is pressed now
		// and its opposite is not, or it already won and its opposite is not
		// pressed now
		win_n[k+1] = in[k+1] & in[k]   & ~fresh[k]   & (fresh[k+1] | win[k+1]);
		win_n[k]   = in[k+1] & in[k]   & ~fresh[k+1] & (fresh[k]   | win[k]);
		res[k+1]   = in[k+1] & (~in[k]   | win_n[k+1]);
		res[k]     = in[k]   & (~in[k+1] | win_n[k]);
	end
end

always @(posedge clk) begin
	prev <= in;
	win  <= win_n;
end

assign out = res;

endmodule
