`default_nettype none

module tt_um_vga_example(
    input  wire [7:0] ui_in,   // ungenutzt (unterdrückt)
    output wire [7:0] uo_out,  // TinyVGA PMOD
    input  wire [7:0] uio_in,  // ungenutzt
    output wire [7:0] uio_out, // 0
    output wire [7:0] uio_oe,  // 0
    input  wire       ena,     // ungenutzt
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

    // Unterdrücke Warnungen für ungenutzte Eingänge
    wire _unused_ok = &{ena, uio_in, ui_in};

    // VGA-Timing-Generator
    hvsync_generator hvsync_gen(
        .clk(clk),
        .reset(~rst_n),
        .hsync(hsync),
        .vsync(vsync),
        .display_on(video_active),
        .hpos(pix_x),
        .vpos(pix_y)
    );

    // vsync → clk synchronisieren und Frame-Tick erzeugen
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
    wire frame_tick = (vsync_q1 & ~vsync_q2); // steigende Flanke von vsync

    // Baum (statisch)
    wire tree_trunk  = (pix_x >= 10'd320 && pix_x <= 10'd330 && pix_y >= 10'd240 && pix_y <= 10'd480);
    wire tree_leaves = (pix_x >= 10'd300 && pix_x <= 10'd350 && pix_y >= 10'd200 && pix_y <  10'd240);

    // Fallende Blätter (kleine 5x5-Sprites)
    localparam integer N_LEAVES = 8;
    localparam [9:0]   TOP_Y    = 10'd200;
    localparam [9:0]   BOT_Y    = 10'd480;
    localparam [9:0]   LEAF_W   = 10'd5;
    localparam [9:0]   RESET_Y  = 10'd200;

    reg [9:0] leaf_x [0:N_LEAVES-1];
    reg [9:0] leaf_y [0:N_LEAVES-1];

    integer i;

    // Initialisierung & Bewegung (einzige sequentielle Logik)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Startpositionen verteilt unterhalb des Laubwerks
            for (i = 0; i < N_LEAVES; i = i + 1) begin
                leaf_x[i] <= 10'd305 + (i * 10'd5);
                leaf_y[i] <= TOP_Y + (i[9:0] * 10'd2); // leicht versetzt
            end
        end else begin
            // Ein Schritt pro Frame
            if (frame_tick) begin
                for (i = 0; i < N_LEAVES; i = i + 1) begin
                    if (leaf_y[i] < BOT_Y)
                        leaf_y[i] <= leaf_y[i] + 10'd1;
                    else begin
                        leaf_y[i] <= RESET_Y;
                        // Optional: X leicht variieren, um Muster zu brechen (deterministisch)
                        leaf_x[i] <= (leaf_x[i] + 10'd7 <= 10'd350) ? (leaf_x[i] + 10'd7) : 10'd305;
                    end
                end
            end
        end
    end

    // Pixel-Farbzuweisung
    always @* begin
        R = 2'b00;
        G = 2'b00;
        B = 2'b00;

        if (video_active) begin
            if (tree_trunk) begin
                // braun-ish
                R = 2'b10;
                G = 2'b01;
            end else if (tree_leaves) begin
                // grün
                G = 2'b11;
            end else begin
                // Prüfe, ob aktuelles Pixel in einem Blatt-Sprite liegt
                reg leaf_here;
                integer j;
                leaf_here = 1'b0;
                for (j = 0; j < N_LEAVES; j = j + 1) begin
                    if ( (pix_x >= leaf_x[j]) && (pix_x < (leaf_x[j] + LEAF_W)) &&
                         (pix_y >= leaf_y[j]) && (pix_y < (leaf_y[j] + LEAF_W)) ) begin
                        leaf_here = 1'b1;
                    end
                end
                if (leaf_here) begin
                    // gelblich/hell (Herbstblatt)
                    R = 2'b11;
                    G = 2'b10;
                end
            end
        end
    end

endmodule
