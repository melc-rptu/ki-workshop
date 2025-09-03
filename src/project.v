`default_nettype none

module hvsync_generator (
    input  wire clk,
    input  wire reset,
    output reg  hsync,
    output reg  vsync,
    output wire display_on,
    output reg  [9:0] hpos,
    output reg  [9:0] vpos
);
    parameter H_DISPLAY = 640;
    parameter H_BACK    = 48;
    parameter H_FRONT   = 16;
    parameter H_SYNC    = 96;
    parameter V_DISPLAY = 480;
    parameter V_TOP     = 33;
    parameter V_BOTTOM  = 10;
    parameter V_SYNC    = 2;

    localparam H_SYNC_START = H_DISPLAY + H_FRONT;
    localparam H_SYNC_END   = H_DISPLAY + H_FRONT + H_SYNC - 1;
    localparam H_MAX        = H_DISPLAY + H_BACK + H_FRONT + H_SYNC - 1;
    localparam V_SYNC_START = V_DISPLAY + V_BOTTOM;
    localparam V_SYNC_END   = V_DISPLAY + V_BOTTOM + V_SYNC - 1;
    localparam V_MAX        = V_DISPLAY + V_TOP + V_BOTTOM + V_SYNC - 1;

    wire hmaxxed = (hpos == H_MAX) || reset;
    wire vmaxxed = (vpos == V_MAX) || reset;

    always @(posedge clk) begin
        if (reset) begin
            hpos  <= 0;
            hsync <= 0;
        end else begin
            if (hmaxxed) 
                hpos <= 0;
            else
                hpos <= hpos + 1;

            hsync <= (hpos >= H_SYNC_START && hpos <= H_SYNC_END);
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            vpos  <= 0;
            vsync <= 0;
        end else if (hmaxxed) begin
            if (vmaxxed)
                vpos <= 0;
            else
                vpos <= vpos + 1;

            vsync <= (vpos >= V_SYNC_START && vpos <= V_SYNC_END);
        end
    end

    assign display_on = (hpos < H_DISPLAY) && (vpos < V_DISPLAY);
endmodule

module tt_um_example(
    input  wire [7:0] ui_in,      // Dedizierte Eingänge
    output wire [7:0] uo_out,     // Dedizierte Ausgänge
    input  wire [7:0] uio_in,     // I/Os: Eingangspfad
    output wire [7:0] uio_out,    // I/Os: Ausgangspfad
    output wire [7:0] uio_oe,     // I/Os: Enable-Pfad (aktiv hoch: 0=Eingang, 1=Ausgang)
    input  wire       ena,        // immer 1, wenn das Design versorgt ist, kann ignoriert werden
    input  wire       clk,        // Takt
    input  wire       rst_n       // reset_n - niedrig zum Zurücksetzen
);
    // VGA-Signale
    wire hsync;
    wire vsync;
    wire [1:0] R;
    wire [1:0] G;
    wire [1:0] B;
    wire video_active;
    wire [9:0] pix_x;
    wire [9:0] pix_y;

    // TinyVGA PMOD
    assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

    // Unbenutzte Ausgänge werden auf 0 gesetzt.
    assign uio_out = 0;
    assign uio_oe  = 0;

    // Unterdrückung von Warnungen für unbenutzte Signale
    wire _unused_ok = &{ena, ui_in, uio_in};

    // Definition des roten Rechtecks
    localparam RECT_X_START = 100;
    localparam RECT_Y_START = 100;
    localparam RECT_WIDTH   = 200;
    localparam RECT_HEIGHT  = 150;

    wire inside_rectangle = (pix_x >= RECT_X_START) && (pix_x < RECT_X_START + RECT_WIDTH) &&
                            (pix_y >= RECT_Y_START) && (pix_y < RECT_Y_START + RECT_HEIGHT);

    assign R = video_active && inside_rectangle ? 2'b11 : 2'b00; // Rote Farbe
    assign G = 2'b00; // Kein Grün
    assign B = 2'b00; // Kein Blau

    // In-Stand-Setzen des VGA-Signalgenerators
    hvsync_generator hvsync_gen(
        .clk(clk),
        .reset(~rst_n),
        .hsync(hsync),
        .vsync(vsync),
        .display_on(video_active),
        .hpos(pix_x),
        .vpos(pix_y)
    );
endmodule
