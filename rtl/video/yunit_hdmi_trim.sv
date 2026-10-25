//============================================================================
//  yunit_hdmi_trim.sv - HDMI Top Row Pixel Fix
//
//  Copyright (C) 2026 Gm0rk. Distributed under GNU GPL v3 or later.
//
//  The Y Unit's first picture line carries stray pixels (Mortal Kombat: bad
//  pixels at the left of the title screen's top line, a couple of blinking
//  ones during a fight). A cabinet's overscan hides the line; HDMI shows the
//  whole picture.
//
//  This stage hides that line from the MiSTer scaler and from nothing else:
//  it takes the pixel enables of the first active line of every frame away
//  from CE_PIXEL. The framework's scaler (ascal) and the video information
//  the HPS reads only look at the signals on a pixel enable, so they never
//  see the line: the frame they get is one line shorter and the picture
//  starts at the second line. The analog connector does not use the pixel
//  enable (its picture, blanking and sync are the same signals as without
//  this stage), so the line is still in the analog picture.
//
//  Only the enable is changed: RGB, sync and DE are not touched. The hidden
//  line is the first line with DE after VSync, i.e. the first line of the
//  scaler's image.
//
//  With a scandoubler effect the stream has two lines for every picture
//  line; both are hidden (lines2).
//
//  The setting is read at VSync, so it changes between frames, never in the
//  middle of a line.
//============================================================================

module yunit_hdmi_trim
(
	input  clk,          // video clock (CLK_VIDEO)
	input  enable,       // OSD: HDMI Top Row Pixel Fix
	input  lines2,       // the stream has two lines per picture line (scandoubler)

	input  ce_in,        // pixel enable of the stream
	input  de_in,        // picture area, valid on ce_in
	input  vs_in,        // VSync, active high

	output ce_out        // pixel enable for the framework
);

reg       vs_d = 1'b0, de_d = 1'b0;
reg       pend = 1'b0;   // the first picture line of this frame is still to come (setting on)
reg [1:0] left = 2'd0;   // lines still to hide

always @(posedge clk) begin
	vs_d <= vs_in;
	de_d <= de_in;

	if (vs_in & ~vs_d) begin
		pend <= enable;
		left <= lines2 ? 2'd2 : 2'd1;
	end
	else if (pend & de_d & ~de_in) begin            // a picture line has just ended
		left <= left - 2'd1;
		if (left == 2'd1) pend <= 1'b0;
	end
end

assign ce_out = ce_in & ~(pend & de_in);

endmodule
