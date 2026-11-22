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

module femto_bio #(parameter RAM_WIDTH=11, parameter NUM_CORES=2) (
    `ifdef USE_POWER_PINS_FOR_RAM
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

    reg [23:0] event_flags_r;
    reg [23:0] event_flags_new;
    wire [31:24] event_flags_fifo;
    wire [31:0] event_flags = {event_flags_fifo, event_flags_r};

    wire [31:0] gpio_data_out_core [NUM_CORES-1:0];
    wire [31:0] gpio_mask_out_core [NUM_CORES-1:0];
    wire gpio_set_out_core [NUM_CORES-1:0];
    wire gpio_set_oe_core [NUM_CORES-1:0];

    wire [31:0] fifo_wdata_core [NUM_CORES-1:0];
    wire [3:0] fifo_wr_core [NUM_CORES-1:0];
    wire [3:0] fifo_rd_core [NUM_CORES-1:0];
    wire [3:0] host_fifo_wr;
    wire [3:0] host_fifo_rd;

    wire [23:0] event_flags_set_core [NUM_CORES-1:0];
    wire [23:0] event_flags_clr_core [NUM_CORES-1:0];
    wire [23:0] host_event_set;
    wire [23:0] host_event_clr;

    wire quantum [NUM_CORES-1:0];
    wire set_qdiv [NUM_CORES-1:0];
    wire [23:0] div_out [NUM_CORES-1:0];

    integer i;
    genvar k;

    generate
    for(k = 0; k < NUM_CORES; k = k + 1) begin: cores
        femto_bio_core #(.RAM_WIDTH(RAM_WIDTH), .CORE_ID(k)) i_femto_bio_core (
        `ifdef USE_POWER_PINS_FOR_RAM
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

        .event_flags(event_flags),
        .event_flags_set(event_flags_set_core[k]),
        .event_flags_clr(event_flags_clr_core[k]),

        .quantum(quantum[k])
    );

    pio_divider i_pio_divider (
        .clk(clk),
        .reset(~rst_n),
        .div_int(pwdata[31:16]),
        .div_frac(pwdata[15:8]),
        .div_set(set_qdiv[k]),
        .div_out(div_out[k]),
        .penable(quantum[k])
    );
    end
    endgenerate

    always @(*) begin
        fifo_wdata = pwdata;
        fifo_wr = host_fifo_wr;
        fifo_rd = host_fifo_rd;
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
                gpio_data_oe = (gpio_data_oe & ~gpio_mask_out_core[i]) | (gpio_data_out_core[i] & gpio_mask_out_core[i]);
            end
            if (gpio_set_out_core[i]) begin
                gpio_mask_out = gpio_mask_out | gpio_mask_out_core[i];
                gpio_data_out = (gpio_data_out & ~gpio_mask_out_core[i]) | (gpio_data_out_core[i] & gpio_mask_out_core[i]);
            end
        end
    end

    always @(*) begin
        event_flags_new = event_flags_r;
        for (i = NUM_CORES-1; i >= 0; i = i - 1) begin
            event_flags_new = (event_flags_new | event_flags_set_core[i]) & ~event_flags_clr_core[i];
        end
        event_flags_new = (event_flags_new | host_event_set) & ~host_event_clr;
    end

    always @(posedge clk) begin
        if (~rst_n)
            event_flags_r <= 24'b0;
        else
            event_flags_r <= event_flags_new;
    end

    // Placeholder - set event flags to empty and full for each FIFO, full BIO has this configurable.
    assign event_flags_fifo = {
        ~fifo_writable[3], ~fifo_readable[3],
        ~fifo_writable[2], ~fifo_readable[2],
        ~fifo_writable[1], ~fifo_readable[1],
        ~fifo_writable[0], ~fifo_readable[0]
    };

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

    reg config_addr;
    wire config_write = config_addr & psel & penable & pwrite;
    wire config_read = config_addr & psel & penable & ~pwrite;
    
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

            assign host_fifo_wr[k] = config_write & (paddr[14:0] == 15'h0010 + (4 * k));
            assign host_fifo_rd[k] = config_read & (paddr[14:0] == 15'h0020 + (4 * k));
        end
    endgenerate

    reg [31:0] prdata_config;
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

    wire [15:0] ram_size = 1 << RAM_WIDTH;
    wire [7:0] num_cores = NUM_CORES;
    always @(*) begin
        case (paddr[14:0])
            /* verilator lint_off WIDTHEXPAND */
            15'h0000: prdata_config = core_enable;  // ctrl
            /* verilator lint_on WIDTHEXPAND */
            15'h0004: prdata_config = {ram_size, num_cores, 8'h80};  // cfg
            15'h000c: prdata_config = {16'b0, fifo_level[3], fifo_level[2], fifo_level[1], fifo_level[0]};  // flevel
            15'h0020: prdata_config = fifo_rdata[0];
            15'h0024: prdata_config = fifo_rdata[1];
            15'h0028: prdata_config = fifo_rdata[2];
            15'h002c: prdata_config = fifo_rdata[3];
            15'h0040: prdata_config = event_flags;  // event status
            default: prdata_config = 32'b0;
        endcase

        /* verilator lint_off WIDTHEXPAND */
        for (i = 0; i < NUM_CORES; i = i + 1)
            if (paddr[14:0] == 15'h0050 + (4 * i))
                prdata_config = {div_out[i], 8'b0};
        /* verilator lint_on WIDTHEXPAND */
    end

    reg [31:0] prdata_from_cores;
    always @(*) begin
        prdata_from_cores = 32'b0;
        for (i = NUM_CORES-1; i >= 0; i = i - 1) begin
            if (core_addr[i])
                prdata_from_cores = prdata_core[i];
        end
    end

    always @(*) begin
        if (config_addr)
            prdata_r = prdata_config;
        else 
            prdata_r = prdata_from_cores;
    end

    generate
        for(k = 0; k < NUM_CORES; k = k + 1) begin: core_apb_wiring

        assign core_sel[k] = paddr[15] & (paddr[14:13] == k);

        assign set_qdiv[k] = config_write & (paddr[14:0] == 15'h0050 + (4 * k));

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
                if (config_write & (paddr[14:0] == 15'b0)) begin
                    core_enable[k] <= pwdata[k];
                end
            end
        end
        end
    endgenerate

    assign host_event_set = config_write & (paddr[14:0] == 15'h0038) ? pwdata[23:0] : 24'b0;
    assign host_event_clr = config_write & (paddr[14:0] == 15'h003c) ? pwdata[23:0] : 24'b0;

endmodule
