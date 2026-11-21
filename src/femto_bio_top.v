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

module femto_bio #(parameter RAM_WIDTH=10, parameter NUM_CORES=2) (
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

    wire [31:0] prdata_core [NUM_CORES-1:0];
    wire [NUM_CORES-1:0] pready_core;
    reg  [NUM_CORES-1:0] core_enable;
    wire [NUM_CORES-1:0] core_sel;

    reg [31:0] gpio_data_out;
    reg [31:0] gpio_mask_out;
    reg [31:0] gpio_data_oe;
    reg [31:0] gpio_mask_oe;

    reg [31:0] fifo_wdata;
    reg [3:0] fifo_wr;
    reg [3:0] fifo_rd;
    wire [31:0] fifo_rdata [3:0];
    wire [3:0] fifo_readable;
    wire [3:0] fifo_writable;
    wire [3:0] fifo_level [3:0];

    wire [31:0] gpio_data_out_core [NUM_CORES-1:0];
    wire [31:0] gpio_mask_out_core [NUM_CORES-1:0];
    wire gpio_set_out_core [NUM_CORES-1:0];
    wire gpio_set_oe_core [NUM_CORES-1:0];

    wire [31:0] fifo_wdata_core [NUM_CORES-1:0];
    wire [3:0] fifo_wr_core [NUM_CORES-1:0];
    wire [3:0] fifo_rd_core [NUM_CORES-1:0];

    integer i;
    genvar k;

    generate
    for(k = 0; k < NUM_CORES; k = k + 1) begin: cores
        femto_bio_core #(.RAM_WIDTH(RAM_WIDTH)) i_femto_bio_core (
        `ifdef USE_POWER_PINS
        .VDD  (VDD),
        .VSS  (VSS),
        `endif

        .clk(clk),
        .rst_n(rst_n),
        .core_enable(core_enable[k]),

        .paddr(paddr[12:0]),
        .psel(psel && core_sel[k]),
        .penable(penable),
        .pwrite(pwrite),
        .pwdata(pwdata),
        .prdata(prdata_core[k]),
        .pready(pready_core[k]),

        .gpio_data_out(gpio_data_out_core[k]),
        .gpio_mask_out(gpio_mask_out_core[k]),
        .gpio_set_out(gpio_set_out_core[k]),
        .gpio_set_oe(gpio_set_oe_core[k]),
        .gpio_in(gpio_in),

        .fifo_wdata(fifo_wdata_core[k]),
        .fifo_wr(fifo_wr_core[k]),
        .fifo_rd(fifo_rd_core[k]),
        .fifo_rdata_0(fifo_rdata[0]),
        .fifo_rdata_1(fifo_rdata[1]),
        .fifo_rdata_2(fifo_rdata[2]),
        .fifo_rdata_3(fifo_rdata[3]),
        .fifo_readable(fifo_readable),
        .fifo_writable(fifo_writable),

        .quantum(1'b1)
    );
    end
    endgenerate

    always @(*) begin
        fifo_wdata = 32'b0;
        fifo_wr = 4'b0;
        fifo_rd = 4'b0;
        for (i = NUM_CORES-1; i >= 0; i = i - 1) begin
            if (fifo_wr_core[i] != 4'b0) begin
                fifo_wdata = fifo_wdata_core[i];
                fifo_wr = fifo_wr_core[i];
            end
            fifo_rd = fifo_rd | fifo_rd_core[i];
        end
    end

    always @(*) begin
        gpio_data_out = 32'b0;
        gpio_mask_out = 32'b0;
        gpio_data_oe = 32'b0;
        gpio_mask_oe = 32'b0;
        for (i = NUM_CORES-1; i >= 0; i = i - 1) begin
            if (gpio_set_oe_core[i]) begin
                gpio_mask_oe = gpio_mask_oe | gpio_mask_out_core[i];
                gpio_data_oe = gpio_data_oe | (gpio_data_out_core[i] & gpio_mask_out_core[i]);
            end
            if (gpio_set_out_core[i]) begin
                gpio_mask_out = gpio_mask_out | gpio_mask_out_core[i];
                gpio_data_out = gpio_data_out | (gpio_data_out_core[i] & gpio_mask_out_core[i]);
            end
        end
    end

    always @(posedge clk) begin
        if (~rst_n) begin
            gpio_out <= 32'b0;
            gpio_oe <= 32'b0;
        end
        else begin
            gpio_out <= (gpio_out & ~gpio_mask_out) | (gpio_data_out & gpio_mask_out);
            gpio_oe <= (gpio_oe & ~gpio_mask_oe) | (gpio_data_oe & gpio_mask_oe);
        end
    end

    generate
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
    reg [NUM_CORES-1:0] core_addr;
    
    always @(posedge clk) begin
        if (~rst_n)
            config_addr <= 0;
        else
            config_addr <= ~paddr[15];
    end

    reg [31:0] prdata_r;
    assign pready = config_addr ? psel & penable :
                    |(core_addr & pready_core);
    assign prdata = prdata_r;
    assign prdata_config = {31'b0, core_enable[0]};

    always @(*) begin
        prdata_r = 32'b0;
        if (config_addr)
            prdata_r = prdata_config;
        else begin
            for (i = NUM_CORES-1; i >= 0; i = i - 1) begin
                if (core_addr[i])
                    prdata_r = prdata_core[i];
            end
        end
    end

    generate
        for(k = 0; k < NUM_CORES; k = k + 1) begin: core_apb_wiring

        assign core_sel[k] = paddr[15] & (paddr[14:13] == k);

        always @(posedge clk) begin
            if (~rst_n)
                core_addr[k] <= 0;
            else
                core_addr[k] <= core_sel[k];
        end

        always @(posedge clk) begin
            if (~rst_n) begin
                core_enable[k] <= 1'b0;
            end
            else begin
                if (config_addr & psel & penable & pwrite & (paddr[14:0] == 15'b0)) begin
                    core_enable[k] <= pwdata[k];
                end
            end
        end
        end
    endgenerate


endmodule
