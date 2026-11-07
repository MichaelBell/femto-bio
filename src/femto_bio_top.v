/* Copyright 2026 (c) Michael Bell
   SPDX-License-Identifier: BSD-3-Clause
   
   A Femto-BIO CPU group.
   A 16-bit wide RAM internal to this instance is used for instruction/stack memory. */

`default_nettype none

// APB peripheral address map
// 0x0000 - 0x7FFF: Global Config
// 0x8000 - 0x8FFF: Core 0 config
// 0x9000 - 0x9FFF: Core 0 memory
// 0xA000 - 0xAFFF: Core 1 config
// 0xB000 - 0xBFFF: Core 1 memory
// 0xC000 - 0xCFFF: Core 2 config
// 0xD000 - 0xDFFF: Core 2 memory
// 0xE000 - 0xEFFF: Core 3 config
// 0xF000 - 0xFFFF: Core 3 memory

module femto_bio #(parameter RAM_WIDTH=10, parameter NUM_CORES=1) (
    `ifdef USE_POWER_PINS
    inout  wire VDD,
    inout  wire VSS,
    `endif

    input clk,
    input rst_n,

    output reg [31:0] gpio_out,
    output reg [31:0] gpio_oe,
    input  [31:0] gpio_in,

    // APB interface for configuration
    input  [15:0] paddr,
    input         psel,
    input         penable,
    input         pwrite,
    input  [31:0] pwdata,
    output [31:0] prdata,
    output        pready
);

    wire [31:0] prdata_core [NUM_CORES];
    wire        pready_core [NUM_CORES];
    reg         core_enable [NUM_CORES];

    wire [31:0] gpio_data_out;
    wire [31:0] gpio_mask_out;
    wire gpio_set_out;
    wire gpio_set_oe;

    wire [31:0] fifo_wdata;
    wire [3:0] fifo_wr;
    wire [3:0] fifo_rd;
    wire [31:0] fifo_rdata [3:0];
    wire [3:0] fifo_readable;
    wire [3:0] fifo_writable;
    wire [3:0] fifo_level [3:0];

    femto_bio_core #(.RAM_WIDTH(RAM_WIDTH)) i_femto_bio_core (
        `ifdef USE_POWER_PINS
        .VDD  (VDD),
        .VSS  (VSS),
        `endif

        .clk(clk),
        .rst_n(rst_n),
        .core_enable(core_enable[0]),

        .paddr(paddr[12:0]),
        .psel(psel && (paddr[15:13] == 3'b100)),
        .penable(penable),
        .pwrite(pwrite),
        .pwdata(pwdata),
        .prdata(prdata_core[0]),
        .pready(pready_core[0]),

        .gpio_data_out(gpio_data_out),
        .gpio_mask_out(gpio_mask_out),
        .gpio_set_out(gpio_set_out),
        .gpio_set_oe(gpio_set_oe),
        .gpio_in(gpio_in),

        .fifo_wdata(fifo_wdata),
        .fifo_wr(fifo_wr),
        .fifo_rd(fifo_rd),
        .fifo_rdata_0(fifo_rdata[0]),
        .fifo_rdata_1(fifo_rdata[1]),
        .fifo_rdata_2(fifo_rdata[2]),
        .fifo_rdata_3(fifo_rdata[3]),
        .fifo_readable(fifo_readable),
        .fifo_writable(fifo_writable),

        .quantum(1'b1)
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

    generate
        genvar k;
        for(k = 0; k < 4; k = k + 1) begin: fifos
            regfifo regfifo(
                .reset(~rst_n),
                .aclk(clk),
                .wdata(fifo_wdata),
                .we(fifo_wr[k]),
                .writable(fifo_writable[k]),
                .re(fifo_rd[k]),
                .readable(fifo_readable[k]),
                .rdata(fifo_rdata[k]),
                .level(fifo_level[k])
            );
        end
    endgenerate

    reg config_addr;
    wire [31:0] prdata_config;
    reg core_addr [NUM_CORES];
    
    always @(posedge clk) begin
        if (~rst_n)
            config_addr <= 0;
        else
            config_addr <= ~paddr[15];
    end

    generate
        for(k = 0; k < NUM_CORES; k = k + 1) begin: core_apb_wiring
        always @(posedge clk) begin
            if (~rst_n)
                core_addr[k] <= 0;
            else
                core_addr[k] <= paddr[15] & (paddr[14:13] == k);
        end
        end
    endgenerate

    assign pready = config_addr ? psel & penable :
                    core_addr[0] ? pready_core[0] :
                    1'b0;
    assign prdata = config_addr ? prdata_config :
                    core_addr[0] ? prdata_core[0] :
                    32'b0;

    assign prdata_config = {31'b0, core_enable[0]};
    always @(posedge clk) begin
        if (~rst_n) begin
            core_enable[0] <= 1'b0;
        end
        else begin
            if (config_addr & psel & penable & pwrite & (paddr[14:0] == 15'b0)) begin
                core_enable[0] <= pwdata[0];
            end
        end
    end

endmodule
