//============================================================================
//  yunit_listpage - the Move List's page
//
//  Mortal Kombat's Move List has two pages. With the OSD's "Move List" On
//  and the OSD closed, a press of Left or Right on either controller shows
//  the other page; the pad steers the OSD while it is open, so presses then
//  are ignored (and a direction still held when the OSD closes does not
//  count: only a new press does). The list starts on page 1 (page = 0) each
//  time it is switched on.
//
//  Copyright (C) 2026 Gm0rk - GPL-3.0-or-later
//============================================================================

module yunit_listpage
(
	input      clk,
	input      on,      // Move List On
	input      osd,     // OSD open
	input      left,    // either controller's Left
	input      right,   // either controller's Right
	output reg page     // 0 page 1, 1 page 2
);

reg l_d = 1'b0, r_d = 1'b0;

always @(posedge clk) begin
	l_d <= left;
	r_d <= right;

	if (!on)
		page <= 1'b0;
	else if (!osd && ((left & ~l_d) | (right & ~r_d)))
		page <= ~page;
end

initial page = 1'b0;

endmodule
