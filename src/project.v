`default_nettype none

module tt_um_vga_example(
    input  wire [7:0] ui_in,   // Mauskoordinaten und Klick-Status
    output wire [7:0] uo_out,  // Dedizierte Ausgänge
    input  wire [7:0] uio_in,  // IOs: Eingangs-Pfad (ungenutzt)
    output wire [7:0] uio_out, // IOs: Ausgangs-Pfad (0)
    output wire [7:0] uio_oe,  // IOs: Enable-Pfad (0)
    input  wire       ena,     // ignoriert
    input  wire       clk,     // Pixeltakt
    input  wire       rst_n    // aktives Low-Reset
);

    // VGA-Signale
    wire hsync;
    wire vsync;
    reg  [1:0] R;
    reg  [1:0] G;
    reg  [1:0] B;
    wire       video_active;
    wire [9:0] pix_x;
    wire [9:0] pix_y;

    // TinyVGA PMOD
    assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

    // Ungenutzte Ausgänge
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

    // Warnungen vermeiden
    wire _unused_ok = &{ena, uio_in};

    // VGA-Timing
    hvsync_generator hvsync_gen(
        .clk(clk),
        .reset(~rst_n),
        .hsync(hsync),
        .vsync(vsync),
        .display_on(video_active),
        .hpos(pix_x),
        .vpos(pix_y)
    );

    // Baum
    wire tree_trunk  = (pix_x >= 10'd320 && pix_x <= 10'd330 && pix_y >= 10'd240 && pix_y <= 10'd480);
    wire tree_leaves = (pix_x >= 10'd300 && pix_x <= 10'd350 && pix_y >= 10'd200 && pix_y <  10'd240);

    // Blüten
    reg [9:0] blossom_x [0:7];
    reg [9:0] blossom_y [0:7];
    reg [7:0] clicked;

    // Maus (Hinweis: ui_in[7] wird doppelt genutzt – ok, aber ungewohnt)
    wire [3:0] mouse_x_pos = ui_in[3:0];
    wire [3:0] mouse_y_pos = ui_in[7:4];
    wire       right_click = ui_in[7];

    // vsync → clk synchronisieren und rising edge detektieren
    reg vsync_q1, vsync_q2;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vsync_q1 <= 1'b0;
            vsync_q2 <= 1'b0;
        end else begin
            vsync_q1 <= vsync;
            vsync_q2 <= vsync_q1;
        end
    end
    wire frame_tick = (vsync_q1 & ~vsync_q2); // rising edge von vsync in clk-Domäne

    integer i;

    // Einzige sequenzielle Logik für Blüten & Klicks (eine Domäne!)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 8; i = i + 1) begin
                blossom_x[i] <= 10'd305 + i*10'd5;
                blossom_y[i] <= 10'd240;
            end
            clicked <= 8'b0;
        end else begin
            // pro Frame: fallende Bewegung (sofern nicht geklickt)
            if (frame_tick) begin
                for (i = 0; i < 8; i = i + 1) begin
                    if (!clicked[i]) begin
                        if (blossom_y[i] < 10'd480)
                            blossom_y[i] <= blossom_y[i] + 10'd1;
                        else
                            blossom_y[i] <= 10'd240;
                    end
                end
            end

            // Klick-Erkennung (pro Takt abgefragt)
            if (right_click) begin
                for (i = 0; i < 8; i = i + 1) begin
                    // Match nur auf grobe 4-Bit-Koordinaten wie im Original
                    if (!clicked[i] &&
                        (mouse_x_pos == blossom_x[i][3:0]) &&
                        (mouse_y_pos == blossom_y[i][7:4])) begin
                        clicked[i] <= 1'b1;
                    end
                end
            end
        end
    end

    // Farbzuweisung (kombinatorisch)
    always @* begin
        R = 2'b00;
        G = 2'b00;
        B = 2'b00;
        if (video_active) begin
            if (tree_trunk) begin
                R = 2'b10; // braunlich
                G = 2'b01;
            end else if (tree_leaves) begin
                G = 2'b11; // grün
            end else begin
                // Blüten (rosa/weiß), nur wenn nicht geklickt
                for (i = 0; i < 8; i = i + 1) begin
                    if (!clicked[i] &&
                        (pix_x >= blossom_x[i] && pix_x < blossom_x[i] + 10'd5 &&
                         pix_y >= blossom_y[i] && pix_y < blossom_y[i] + 10'd5)) begin
                        R = 2'b11;
                        G = 2'b11;
                    end
                end
            end
        end
    end

endmodule
