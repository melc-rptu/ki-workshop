




`default_nettype none

module tt_um_vga_example(
    input wire [7:0] ui_in, // Maus-Koordination und Klick-Status
    output wire [7:0] uo_out, // Dedizierte Ausgänge
    input wire [7:0] uio_in, // IOs: Eingangs-Pfad (ungenutzt)
    output wire [7:0] uio_out, // IOs: Ausgangs-Pfad (auf 0 gesetzt)
    output wire [7:0] uio_oe, // IOs: Enable-Pfad (auf 0 gesetzt)
    input wire ena, // Immer 1, solange das Design mit Strom versorgt ist (ignoriert)
    input wire clk, // Takt
    input wire rst_n // Aktives Low-Reset
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

    // Ungenutzte Ausgänge auf 0 gesetzt
    assign uio_out = 8'b00000000;
    assign uio_oe  = 8'b00000000;

    // Unterdrücke Warnungen für ungenutzte Signale
    wire _unused_ok = &{ena, uio_in};

    // Instanziierung des VGA-Signalgenerators
    hvsync_generator hvsync_gen(
        .clk(clk),
        .reset(~rst_n),
        .hsync(hsync),
        .vsync(vsync),
        .display_on(video_active),
        .hpos(pix_x),
        .vpos(pix_y)
    );

    // Baum mit grünen Blättern
    wire tree_trunk = (pix_x >= 320 && pix_x <= 330 && pix_y >= 240 && pix_y <= 480); 
    wire tree_leaves = (pix_x >= 300 && pix_x <= 350 && pix_y >= 200 && pix_y < 240);

    // Blüten
    reg [9:0] blossom_x[0:7];
    reg [9:0] blossom_y[0:7];
    reg [7:0] clicked;

    // Mauskoordinaten und Klickstatus
    wire [3:0] mouse_x = ui_in[3:0];
    wire [3:0] mouse_y = ui_in[7:4];
    wire right_click = (~ui_in[8]);

    // Initialisierung der Blüten
    integer i;
    always @(posedge vsync or negedge rst_n) begin
        if (~rst_n) begin
            for (i = 0; i < 8; i = i + 1) begin
                blossom_x[i] <= 305 + i * 5; // Verteilt sie entlang dem Baum
                blossom_y[i] <= 240; // Startposition
                clicked[i] <= 0;
            end
        end else begin
            for (i = 0; i < 8; i = i + 1) begin
                if (clicked[i]) begin
                    blossom_y[i] <= 240; // Zurück an Start
                end else if (blossom_y[i] < 480) begin
                    blossom_y[i] <= blossom_y[i] + 1; // Fallen lassen
                end else begin
                    blossom_y[i] <= 240; // Zurück an Start
                end
            end
        end
    end

    // Klick-Erkennung und Blüten verschwinden lassen
    always @(posedge clk) begin
        if (right_click) begin
            for (i = 0; i < 8; i = i + 1) begin
                if ((mouse_x == blossom_x[i][3:0]) && (mouse_y == blossom_y[i][7:4])) begin
                    clicked[i] <= 1;
                end
            end
        end
    end

    // Farbzuweisung: Baum braun, Blätter grün, Blüten rosa/weiß, wenn nicht geklickt
    assign R = video_active ? (tree_trunk ? 2'b10 : 
                               tree_leaves ? 2'b00 :
                               |(~clicked & ((blossom_x[0] <= pix_x && pix_x < blossom_x[0] + 5 && blossom_y[0] <= pix_y && pix_y < blossom_y[0] + 5) ? 2'b11 : 2'b00))) : 2'b00;
    assign G = video_active ? (tree_trunk ? 2'b01 : 
                               tree_leaves ? 2'b11 :
                               |(~clicked & ((blossom_x[0] <= pix_x && pix_x < blossom_x[0] + 5 && blossom_y[0] <= pix_y && pix_y < blossom_y[0] + 5) ? 2'b11 : 2'b00))) : 2'b00;
    assign B = video_active ? 2'b00 : 2'b00;

endmodule
