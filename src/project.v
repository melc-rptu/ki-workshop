// Stockentenerpel mit Futter und Entenkueken
// Tiny Tapeout / VGA Playground, 640x480 @ ca. 60 Hz
//
// Tastenbelegung im VGA Playground:
// Taste 1 -> ui_in[0] -> links
// Taste 2 -> ui_in[1] -> rechts
// Taste 3 -> ui_in[2] -> hoch
// Taste 4 -> ui_in[3] -> runter

module tt_um_yourgithub_ducklings (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    // VGA-Timing:
    // Horizontal: 640 aktiv + 16 + 96 + 48 = 800
    // Vertikal:   480 aktiv + 10 + 2 + 33 = 525
    reg [9:0] hpos;
    reg [9:0] vpos;

    wire active_video;
    wire hsync;
    wire vsync;

    assign active_video = (hpos < 10'd640) && (vpos < 10'd480);

    // 640x480@60Hz verwendet negative Sync-Pulse.
    assign hsync = !((hpos >= 10'd656) && (hpos < 10'd752));
    assign vsync = !((vpos >= 10'd490) && (vpos < 10'd492));

    // ------------------------------------------------------------------------
    // Eingaben: Tasten 1, 2, 3 und 4
    // ------------------------------------------------------------------------

    wire key_left;
    wire key_right;
    wire key_up;
    wire key_down;
    wire moving;

    assign key_left         = ui_in[1];
    assign key_right        = ui_in[2];
    assign key_up           = ui_in[3];
    assign key_down         = ui_in[4];


    assign moving = key_left || key_right || key_up || key_down;

    // ------------------------------------------------------------------------
    // Spielzustand
    // ------------------------------------------------------------------------

    // Die grosse Ente verwendet eine Bounding-Box von 64 x 64 Pixeln.
    reg [9:0] duck_x;
    reg [9:0] duck_y;
    reg       duck_right;
    reg       walk_phase;

    // Futter verwendet eine Bounding-Box von 12 x 8 Pixeln.
    reg [9:0] food_x;
    reg [9:0] food_y;
    reg       food_present;
    reg [5:0] food_timer;

    // Pseudozufallsgenerator fuer neue Futterpositionen.
    reg [7:0] lfsr;

    // Anzahl sichtbarer Kueken: maximal vier.
    reg [2:0] chick_count;

    wire food_collected;

    assign food_collected =
        food_present &&
        (duck_x < (food_x + 10'd12)) &&
        ((duck_x + 10'd64) > food_x) &&
        (duck_y < (food_y + 10'd8)) &&
        ((duck_y + 10'd64) > food_y);

    // ------------------------------------------------------------------------
    // VGA-Zaehler und Spielsteuerung
    //
    // Alle Positionsaenderungen erfolgen am Ende eines Frames.
    // Dadurch bleibt das Bild innerhalb eines Frames stabil.
    // ------------------------------------------------------------------------

    always @(posedge clk) begin
        if (!rst_n) begin
            hpos         <= 10'd0;
            vpos         <= 10'd0;

            duck_x       <= 10'd280;
            duck_y       <= 10'd260;
            duck_right   <= 1'b1;
            walk_phase   <= 1'b0;

            food_x       <= 10'd450;
            food_y       <= 10'd370;
            food_present <= 1'b1;
            food_timer   <= 6'd0;

            lfsr         <= 8'hA7;
            chick_count  <= 3'd0;
        end else begin
            if (hpos == 10'd799) begin
                hpos <= 10'd0;

                if (vpos == 10'd524) begin
                    vpos <= 10'd0;

                    // Taste 1: nach links.
                    if (key_left) begin
                        duck_right <= 1'b0;

                        if (duck_x >= 10'd2) begin
                            duck_x <= duck_x - 10'd2;
                        end
                    end

                    // Taste 2: nach rechts.
                    else if (key_right) begin
                        duck_right <= 1'b1;

                        // 640 - 64 = 576; Sicherheitsabstand 2 Pixel.
                        if (duck_x <= 10'd574) begin
                            duck_x <= duck_x + 10'd2;
                        end
                    end

                    // Taste 3: nach oben.
                    if (key_up) begin
                        if (duck_y >= 10'd2) begin
                            duck_y <= duck_y - 10'd2;
                        end
                    end

                    // Taste 4: nach unten.
                    else if (key_down) begin
                        // 480 - 64 = 416; Sicherheitsabstand 2 Pixel.
                        if (duck_y <= 10'd414) begin
                            duck_y <= duck_y + 10'd2;
                        end
                    end

                    // Beinanimation nur beim Bewegen.
                    if (moving) begin
                        walk_phase <= ~walk_phase;
                    end

                    // Futter eingesammelt:
                    // Futter verschwindet, ein Kueken kommt dazu.
                    if (food_collected) begin
                        food_present <= 1'b0;
                        food_timer   <= 6'd0;

                        if (chick_count < 3'd4) begin
                            chick_count <= chick_count + 3'd1;
                        end
                    end

                    // Nach 60 Frames, also ca. einer Sekunde,
                    // erscheint das naechste Futter.
                    else if (!food_present) begin
                        if (food_timer == 6'd59) begin
                            food_present <= 1'b1;
                            food_timer   <= 6'd0;

                            // 8-Bit-LFSR weiterschalten.
                            lfsr <= {
                                lfsr[6:0],
                                lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]
                            };

                            // X: 40 bis ca. 550
                            // Y: 350 bis 413, also auf der Wiese.
                            food_x <= 10'd40 + {1'b0, lfsr, 1'b0};
                            food_y <= 10'd350 + {4'b0000, lfsr[5:0]};
                        end else begin
                            food_timer <= food_timer + 6'd1;
                        end
                    end
                end else begin
                    vpos <= vpos + 10'd1;
                end
            end else begin
                hpos <= hpos + 10'd1;
            end
        end
    end

    // ------------------------------------------------------------------------
    // Pixelgenerator
    // ------------------------------------------------------------------------

    reg [1:0] red;
    reg [1:0] green;
    reg [1:0] blue;

    // Lokale Koordinaten im Sprite des Erpels.
    reg [9:0] raw_dx;
    reg [9:0] dx;
    reg [9:0] dy;

    // Pixelmasken des Erpels.
    reg duck_body;
    reg duck_head;
    reg duck_wing;
    reg duck_tail;
    reg duck_neck;
    reg duck_chest;
    reg duck_beak;
    reg duck_eye;
    reg duck_foot;

    // Pixelmasken fuer Futter und Kueken.
    reg food_pixel;
    reg chick0_pixel;
    reg chick1_pixel;
    reg chick2_pixel;
    reg chick3_pixel;

    always @* begin
        // --------------------------------------------------------------------
        // Defaultwerte: verhindern Latches.
        // --------------------------------------------------------------------

        red   = 2'b01;
        green = 2'b10;
        blue  = 2'b11;

        raw_dx = 10'd0;
        dx     = 10'd0;
        dy     = 10'd0;

        duck_body  = 1'b0;
        duck_head  = 1'b0;
        duck_wing  = 1'b0;
        duck_tail  = 1'b0;
        duck_neck  = 1'b0;
        duck_chest = 1'b0;
        duck_beak  = 1'b0;
        duck_eye   = 1'b0;
        duck_foot  = 1'b0;

        food_pixel   = 1'b0;
        chick0_pixel = 1'b0;
        chick1_pixel = 1'b0;
        chick2_pixel = 1'b0;
        chick3_pixel = 1'b0;

        // --------------------------------------------------------------------
        // Hintergrund
        // --------------------------------------------------------------------

        // Himmel.
        red   = 2'b01;
        green = 2'b10;
        blue  = 2'b11;

        // Gruene Wiese.
        if (vpos >= 10'd340) begin
            red   = 2'b00;
            green = 2'b10;
            blue  = 2'b00;
        end

        // Heller Feldweg.
        if (vpos >= 10'd420) begin
            red   = 2'b10;
            green = 2'b10;
            blue  = 2'b01;
        end

        // Wolke links.
        if ((hpos >= 10'd70) && (hpos < 10'd180) &&
            (vpos >= 10'd70) && (vpos < 10'd92)) begin
            red   = 2'b11;
            green = 2'b11;
            blue  = 2'b11;
        end

        if ((hpos >= 10'd105) && (hpos < 10'd155) &&
            (vpos >= 10'd54) && (vpos < 10'd106)) begin
            red   = 2'b11;
            green = 2'b11;
            blue  = 2'b11;
        end

        // Wolke rechts.
        if ((hpos >= 10'd440) && (hpos < 10'd550) &&
            (vpos >= 10'd100) && (vpos < 10'd122)) begin
            red   = 2'b11;
            green = 2'b11;
            blue  = 2'b11;
        end

        if ((hpos >= 10'd475) && (hpos < 10'd525) &&
            (vpos >= 10'd84) && (vpos < 10'd136)) begin
            red   = 2'b11;
            green = 2'b11;
            blue  = 2'b11;
        end

        // --------------------------------------------------------------------
        // Futter
        // --------------------------------------------------------------------

        if (food_present &&
            (hpos >= food_x) &&
            (hpos < (food_x + 10'd12)) &&
            (vpos >= food_y) &&
            (vpos < (food_y + 10'd8))) begin
            food_pixel = 1'b1;
        end

        // --------------------------------------------------------------------
        // Stockentenerpel: 64 x 64 Pixel
        // --------------------------------------------------------------------

        if ((hpos >= duck_x) &&
            (hpos < (duck_x + 10'd64)) &&
            (vpos >= duck_y) &&
            (vpos < (duck_y + 10'd64))) begin

            raw_dx = hpos - duck_x;
            dy     = vpos - duck_y;

            // Beim Blick nach links wird das Sprite gespiegelt.
            if (duck_right) begin
                dx = raw_dx;
            end else begin
                dx = 10'd63 - raw_dx;
            end

            // Grauer Koerper.
            if ((dx >= 10'd8) && (dx < 10'd50) &&
                (dy >= 10'd27) && (dy < 10'd51)) begin
                duck_body = 1'b1;
            end

            if ((dx >= 10'd16) && (dx < 10'd55) &&
                (dy >= 10'd21) && (dy < 10'd56)) begin
                duck_body = 1'b1;
            end

            // Dunkler Schwanz.
            if ((dx >= 10'd2) && (dx < 10'd17) &&
                (dy >= 10'd29) && (dy < 10'd42)) begin
                duck_tail = 1'b1;
            end

            // Dunkler Fluegel.
            if ((dx >= 10'd17) && (dx < 10'd43) &&
                (dy >= 10'd31) && (dy < 10'd45)) begin
                duck_wing = 1'b1;
            end

            // Gruener Kopf.
            if ((dx >= 10'd43) && (dx < 10'd58) &&
                (dy >= 10'd10) && (dy < 10'd29)) begin
                duck_head = 1'b1;
            end

            if ((dx >= 10'd38) && (dx < 10'd62) &&
                (dy >= 10'd15) && (dy < 10'd25)) begin
                duck_head = 1'b1;
            end

            // Weisser Halsring.
            if ((dx >= 10'd42) && (dx < 10'd56) &&
                (dy >= 10'd25) && (dy < 10'd29)) begin
                duck_neck = 1'b1;
            end

            // Braune Brust.
            if ((dx >= 10'd43) && (dx < 10'd53) &&
                (dy >= 10'd29) && (dy < 10'd45)) begin
                duck_chest = 1'b1;
            end

            // Gelber Schnabel.
            if ((dx >= 10'd57) && (dx < 10'd64) &&
                (dy >= 10'd18) && (dy < 10'd25)) begin
                duck_beak = 1'b1;
            end

            // Schwarzes Auge.
            if ((dx >= 10'd51) && (dx < 10'd54) &&
                (dy >= 10'd15) && (dy < 10'd18)) begin
                duck_eye = 1'b1;
            end

            // Orange Beine, zwei Schrittphasen.
            if (walk_phase) begin
                if ((dx >= 10'd22) && (dx < 10'd26) &&
                    (dy >= 10'd50) && (dy < 10'd63)) begin
                    duck_foot = 1'b1;
                end

                if ((dx >= 10'd39) && (dx < 10'd43) &&
                    (dy >= 10'd50) && (dy < 10'd59)) begin
                    duck_foot = 1'b1;
                end
            end else begin
                if ((dx >= 10'd22) && (dx < 10'd26) &&
                    (dy >= 10'd50) && (dy < 10'd59)) begin
                    duck_foot = 1'b1;
                end

                if ((dx >= 10'd39) && (dx < 10'd43) &&
                    (dy >= 10'd50) && (dy < 10'd63)) begin
                    duck_foot = 1'b1;
                end
            end
        end

        // --------------------------------------------------------------------
        // Entenkueken
        //
        // Die Kueken erscheinen hinter der Ente, links von ihr.
        // Jedes Kueken ist ein kleines gelbes 14 x 12 Pixel Rechteck.
        // --------------------------------------------------------------------

        if ((chick_count >= 3'd1) &&
            (duck_x >= 10'd20) &&
            (hpos >= (duck_x - 10'd20)) &&
            (hpos < (duck_x - 10'd6)) &&
            (vpos >= (duck_y + 10'd45)) &&
            (vpos < (duck_y + 10'd57))) begin
            chick0_pixel = 1'b1;
        end

        if ((chick_count >= 3'd2) &&
            (duck_x >= 10'd40) &&
            (hpos >= (duck_x - 10'd40)) &&
            (hpos < (duck_x - 10'd26)) &&
            (vpos >= (duck_y + 10'd45)) &&
            (vpos < (duck_y + 10'd57))) begin
            chick1_pixel = 1'b1;
        end

        if ((chick_count >= 3'd3) &&
            (duck_x >= 10'd60) &&
            (hpos >= (duck_x - 10'd60)) &&
            (hpos < (duck_x - 10'd46)) &&
            (vpos >= (duck_y + 10'd45)) &&
            (vpos < (duck_y + 10'd57))) begin
            chick2_pixel = 1'b1;
        end

        if ((chick_count >= 3'd4) &&
            (duck_x >= 10'd80) &&
            (hpos >= (duck_x - 10'd80)) &&
            (hpos < (duck_x - 10'd66)) &&
            (vpos >= (duck_y + 10'd45)) &&
            (vpos < (duck_y + 10'd57))) begin
            chick3_pixel = 1'b1;
        end

        // --------------------------------------------------------------------
        // Zeichnungsreihenfolge
        // --------------------------------------------------------------------

        // Futter: Orange.
        if (food_pixel) begin
            red   = 2'b11;
            green = 2'b01;
            blue  = 2'b00;
        end

        // Erpel: grauer Koerper.
        if (duck_body) begin
            red   = 2'b10;
            green = 2'b10;
            blue  = 2'b10;
        end

        // Schwanz.
        if (duck_tail) begin
            red   = 2'b00;
            green = 2'b00;
            blue  = 2'b01;
        end

        // Fluegel.
        if (duck_wing) begin
            red   = 2'b01;
            green = 2'b01;
            blue  = 2'b10;
        end

        // Braune Brust.
        if (duck_chest) begin
            red   = 2'b10;
            green = 2'b01;
            blue  = 2'b00;
        end

        // Gruener Kopf.
        if (duck_head) begin
            red   = 2'b00;
            green = 2'b10;
            blue  = 2'b01;
        end

        // Weisser Halsring.
        if (duck_neck) begin
            red   = 2'b11;
            green = 2'b11;
            blue  = 2'b11;
        end

        // Schnabel und Fuesse.
        if (duck_beak || duck_foot) begin
            red   = 2'b11;
            green = 2'b01;
            blue  = 2'b00;
        end

        // Auge zuletzt zeichnen.
        if (duck_eye) begin
            red   = 2'b00;
            green = 2'b00;
            blue  = 2'b00;
        end

        // Entenkueken: Gelb.
        if (chick0_pixel || chick1_pixel ||
            chick2_pixel || chick3_pixel) begin
            red   = 2'b11;
            green = 2'b11;
            blue  = 2'b00;
        end

        // Austastbereich immer schwarz.
        if (!active_video) begin
            red   = 2'b00;
            green = 2'b00;
            blue  = 2'b00;
        end
    end

    // VGA-Playground-Pinbelegung.
    assign uo_out[0] = red[1];
    assign uo_out[1] = green[1];
    assign uo_out[2] = blue[1];
    assign uo_out[3] = vsync;
    assign uo_out[4] = red[0];
    assign uo_out[5] = green[0];
    assign uo_out[6] = blue[0];
    assign uo_out[7] = hsync;

    // Bidirektionale Pins werden nicht verwendet.
    assign uio_out = 8'b00000000;
    assign uio_oe  = 8'b00000000;

endmodule
