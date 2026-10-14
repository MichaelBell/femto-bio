/* Copyright 2026 (c) Michael Bell
   SPDX-License-Identifier: BSD-3-Clause
   
   A Femto-BIO CPU group.
   A 16-bit wide RAM internal to this instance is used for instruction/stack memory. */

`default_nettype none

module femto_bio #(parameter RAM_WIDTH=10) (
    `ifdef USE_POWER_PINS
    inout  wire VDD,
    inout  wire VSS,
    `endif

    input clk,
    input rst_n,

    output reg [31:0] gpio_out,
    output reg [31:0] gpio_oe,
    input  [31:0] gpio_in

);

    wire [31:0] gpio_data_out;
    wire [31:0] gpio_mask_out;
    wire gpio_set_out;
    wire gpio_set_oe;

    femto_bio_core #(.RAM_WIDTH(RAM_WIDTH)) i_femto_bio_core (
        `ifdef USE_POWER_PINS
        .VDD  (VDD),
        .VSS  (VSS),
        `endif

        .clk(clk),
        .rst_n(rst_n),
        .gpio_data_out(gpio_data_out),
        .gpio_mask_out(gpio_mask_out),
        .gpio_set_out(gpio_set_out),
        .gpio_set_oe(gpio_set_oe),
        .gpio_in(gpio_in)
    );

    always @(posedge clk) begin
        if (~rst_n) begin
            gpio_out <= 32'b0;
            gpio_oe <= 32'b0;
        end
        else begin
            if (gpio_set_out) begin
                gpio_out <= (gpio_out & ~gpio_mask_out) | (gpio_data_out & gpio_mask_out);
            end
            if (gpio_set_oe) begin
                gpio_oe <= (gpio_oe & ~gpio_mask_out) | (gpio_data_out & gpio_mask_out);
            end
        end
    end

endmodule