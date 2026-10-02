/*
 * Copyright (c) 2025 Michael Bell
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_ecp5_wrapper (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    inout  wire [7:0] uio,      // Bidir ios
    input  wire       clk,
    input  wire       rst_n,
    output wire       led,
    inout  wire [5:0] an
);

    wire [7:0] uio_in;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;
    wire [5:0] an_in;
    wire [5:0] an_out;
    wire [5:0] an_oe;

    // This seems to work correctly.  Instantiating TRELLIS_IO seems not to work!
    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin
            assign uio[i] = uio_oe[i] ? uio_out[i] : 1'bz;
            assign uio_in[i] = uio[i];
        end
    endgenerate
    generate
        for (i = 0; i < 6; i = i + 1) begin
            assign an[i] = an_oe[i] ? an_out[i] : 1'bz;
            assign an_in[i] = an[i];
        end
    endgenerate

    wire [31:0] gpio_out;
    wire [31:0] gpio_oe;

    femto_bio i_bio(
        .clk(clk),
        .rst_n(rst_n),
        .gpio_out(gpio_out),
        .gpio_oe(gpio_oe),
        .gpio_in({2'b0, an_in, ui_in, uio_in, 8'b0})
    );

    assign an_out = gpio_out[29:24];
    assign an_oe  = gpio_oe[29:24];

    assign uio_out = gpio_out[15:8];
    assign uio_oe  = gpio_oe[15:8];

    assign led = gpio_out[31];
    assign uo_out = gpio_out[7:0];

endmodule
