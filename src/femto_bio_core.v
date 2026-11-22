/* Copyright 2026 (c) Michael Bell
   SPDX-License-Identifier: BSD-3-Clause
   
   A Femto-BIO CPU instance.
   A 16-bit wide RAM internal to this instance is used for instruction/stack memory. */

`default_nettype none

module femto_bio_core #(parameter RAM_WIDTH=10, CORE_ID=0) (
    `ifdef USE_POWER_PINS_FOR_RAM
    inout  wire VDD,
    inout  wire VSS,
    `endif

    input clk,
    input rst_n,
    input core_enable,

    // APB interface
    input  [12:0] paddr,
    input         psel,
    input         penable,
    input         pwrite,
    input  [31:0] pwdata,
    output [31:0] prdata,
    output        pready,

    output reg [31:0] gpio_data_out,
    output reg [31:0] gpio_mask_out,
    output reg        gpio_set_out,
    output reg        gpio_set_oe,
    input  [31:0] gpio_in,

    output wire [31:0] fifo_wdata,
    output reg  [3:0]  fifo_wr,
    output wire [3:0]  fifo_rd,

    input  [31:0]      fifo_rdata_0,
    input  [31:0]      fifo_rdata_1,
    input  [31:0]      fifo_rdata_2,
    input  [31:0]      fifo_rdata_3,
    input  [3:0]       fifo_readable,
    input  [3:0]       fifo_writable,

    input  [31:0]      event_flags,
    output reg [23:0]  event_flags_set,
    output reg [23:0]  event_flags_clr,

    input              quantum

);

    wire [31:0] femto_addr;
    wire [31:0] femto_wdata;
    wire [31:0] femto_rdata;
    wire  [3:0] femto_mask;
    wire        femto_half;
    wire        femto_wstrb;
    wire        femto_rstrb;
    wire        femto_rinstr;
    wire        femto_rbusy;
    wire        femto_wbusy;

    wire [RAM_WIDTH-1:0] ram_addr;
    wire [31:0] ram_wdata;
    wire [31:0] ram_rdata;
    wire  [3:0] ram_mask;
    wire        ram_half;
    wire        ram_wstrb;
    wire        ram_rstrb;
    wire        ram_rinstr;
    wire        ram_rbusy;
    wire        ram_wbusy;

    wire [4:0]  femto_rd_id;
    wire [31:0] femto_rd_wdata;
    wire [4:0]  femto_rs1_id;
    wire [4:0]  femto_rs2_id;
    reg  [31:0] femto_rs1_rdata;
    reg  [31:0] femto_rs2_rdata;
    wire        femto_rd_write;
    wire        femto_rs1_read;
    wire        femto_rs2_read;
    reg        femto_reg_wbusy;
    reg         femto_reg_rbusy;

    // Maybe move these into the femto BIO reg file to allow
    // them to be implemented as latches.
    reg [31:0] gpio_action_mask;
    reg [31:0] event_mask;

    FemtoRV32 #(.PC_WIDTH(RAM_WIDTH)) i_femtorv(
        .clk(clk),
        .resetn(rst_n & core_enable),

        .mem_addr(femto_addr),
        .mem_wdata(femto_wdata),
        .mem_wstrb(femto_wstrb),
        .mem_mask(femto_mask),
        .mem_half(femto_half),
        .mem_rdata(femto_rdata),
        .mem_rstrb(femto_rstrb),
        .mem_rinstr(femto_rinstr),
        .mem_rbusy(femto_rbusy),
        .mem_wbusy(femto_wbusy),

        .rd_id(femto_rd_id),      // Destination register for access to x16+
        .rd_wdata(femto_rd_wdata),
        .rs1_id(femto_rs1_id),     // Source register 1 for access to x16+
        .rs2_id(femto_rs2_id),     // Source register 2 for access to x16+
        .rs1_rdata(femto_rs1_rdata),
        .rs2_rdata(femto_rs2_rdata),
        .rd_write(femto_rd_write),   // asserted if the destination register is being written
        .rs1_read(femto_rs1_read),   // asserted if source register 1 is being read
        .rs2_read(femto_rs2_read),   // asserted if source register 2 is being read
        .reg_wbusy(femto_reg_wbusy),  // asserted while register write should block
        .reg_rbusy(femto_reg_rbusy)   // asserted while register read should block
    );

    femto_ram_mux #(.RAM_WIDTH(RAM_WIDTH)) i_femtoram_mux (
        .clk(clk),
        .rst_n(rst_n),

        .paddr(paddr[RAM_WIDTH-1:0]),
        .psel(psel & paddr[12]),
        .penable(penable),
        .pwrite(pwrite),
        .pwdata(pwdata),
        .prdata(prdata),
        .pready(pready),

        .core_rstrb(femto_rstrb),
        .core_rinstr(femto_rinstr),
        .core_wstrb(femto_wstrb),
        .core_mask(femto_mask),
        .core_addr(femto_addr[RAM_WIDTH-1:0]),
        .core_half(femto_half),
        .core_rbusy(femto_rbusy),
        .core_wbusy(femto_wbusy),
        .core_wdata(femto_wdata),
        .core_rdata(femto_rdata),

        .ram_rstrb(ram_rstrb),
        .ram_rinstr(ram_rinstr),
        .ram_wstrb(ram_wstrb),
        .ram_mask(ram_mask),
        .ram_addr(ram_addr),
        .ram_half(ram_half),
        .ram_rbusy(ram_rbusy),
        .ram_wbusy(ram_wbusy),
        .ram_wdata(ram_wdata),
        .ram_rdata(ram_rdata)
    );

    femto_ram #(.RAM_WIDTH(RAM_WIDTH)) i_femtoram (
        `ifdef USE_POWER_PINS_FOR_RAM
        .VDD  (VDD),
        .VSS  (VSS),
        `endif

        .clk(clk),
        .rst_n(rst_n),
        .rstrb(ram_rstrb),
        .rinstr(ram_rinstr),
        .wstrb(ram_wstrb),
        .mask(ram_mask),
        .addr(ram_addr),
        .half(ram_half),
        .rbusy(ram_rbusy),
        .wbusy(ram_wbusy),
        .data_in(ram_wdata),
        .data_out(ram_rdata)
    );

    reg [29:0] clk_count;
    always @(posedge clk) begin
        if (!rst_n)
            clk_count <= 30'b0;
        else if (core_enable)
            clk_count <= clk_count + 1;
    end

    // High reg read handling
    integer i;
    reg [31:0] reg_rdata;
    always @(*) begin
        for (i = 0; i < 2; i = i + 1) begin
            case (i == 0 ? femto_rs1_id : femto_rs2_id)
            5'd16: reg_rdata = fifo_rdata_0;
            5'd17: reg_rdata = fifo_rdata_1;
            5'd18: reg_rdata = fifo_rdata_2;
            5'd19: reg_rdata = fifo_rdata_3;

            // x21 read: gpio pins -> x21
            5'd21: reg_rdata = gpio_in;

            // x26 read: gpio action mask -> x26
            5'd26: reg_rdata = gpio_action_mask;

            5'd27: reg_rdata = event_mask;

            // x30 read: event flags -> x30
            5'd30: reg_rdata = event_flags;

            // x31 read: [31:30] -> core ID; [29:0] -> cpu clocks since reset
            5'd31: reg_rdata = {CORE_ID[1:0], clk_count};

            default: reg_rdata = 32'b0;
            endcase

            if (i == 0)
                femto_rs1_rdata = reg_rdata;
            else
                femto_rs2_rdata = reg_rdata;
        end
    end

    always @(*) begin
        femto_reg_rbusy = 1'b0;
        for (i = 0; i < 2; i = i + 1) begin
            case (i == 0 ? femto_rs1_id : femto_rs2_id)
            5'd16: femto_reg_rbusy = femto_reg_rbusy || !fifo_readable[0];
            5'd17: femto_reg_rbusy = femto_reg_rbusy || !fifo_readable[1];
            5'd18: femto_reg_rbusy = femto_reg_rbusy || !fifo_readable[2];
            5'd19: femto_reg_rbusy = femto_reg_rbusy || !fifo_readable[3];
            default: ;
            endcase
        end
    end

    always @(*) begin
        case (femto_rd_id)
        5'd16: femto_reg_wbusy = !fifo_writable[0];
        5'd17: femto_reg_wbusy = !fifo_writable[1];
        5'd18: femto_reg_wbusy = !fifo_writable[2];
        5'd19: femto_reg_wbusy = !fifo_writable[3];
        5'd20: femto_reg_wbusy = !quantum;
        default: femto_reg_wbusy = 1'b0;
        endcase
    end

    wire [31:0] masked_gpio_set = femto_rd_wdata & gpio_action_mask;
    wire [31:0] masked_gpio_clear = ~femto_rd_wdata & gpio_action_mask;

    always @(posedge clk) begin
        if (!rst_n) begin
            gpio_action_mask <= 32'b0;
            event_mask <= 32'b0;
        end
        else if (femto_rd_write) begin
            case (femto_rd_id)

            // x26 write: update the gpio action mask
            5'd26: gpio_action_mask <= femto_rd_wdata;

            // x27 write: mask event sensitivity bits
            5'd27: event_mask <= femto_rd_wdata;

            default: ;
            endcase
        end
    end

    always @(*) begin
        gpio_data_out = 32'b0;
        gpio_mask_out = 32'b0;
        gpio_set_out = 1'b0;
        gpio_set_oe = 1'b0;
        fifo_wr = 4'b0;
        event_flags_set = 24'b0;
        event_flags_clr = 24'b0;

        if (femto_rd_write)
        case (femto_rd_id)
            // x16-x19 - FIFO write
            5'd16: fifo_wr = 4'b0001;
            5'd17: fifo_wr = 4'b0010;
            5'd18: fifo_wr = 4'b0100;
            5'd19: fifo_wr = 4'b1000;

            // x21 write: (x26 & x21) -> gpio pins
            5'd21: begin
                gpio_data_out = femto_rd_wdata;
                gpio_mask_out = gpio_action_mask;
                gpio_set_out = 1'b1;
            end

            // x22 write: (x26 & x22) -> a `1` in x22 will set corresponding pin on gpio
            5'd22: begin
                gpio_data_out = 32'hffffffff;
                gpio_mask_out = masked_gpio_set;
                gpio_set_out = 1'b1;
            end

            // TODO: Maybe change this to a regular set pattern - I'm not convinced this oddity in the BIO design is useful.
            // x23 write: (x26 & ~x23) -> a `0` in x23 will clear corresponding pin on gpio
            5'd23: begin
                gpio_data_out = 32'b0;
                gpio_mask_out = masked_gpio_clear;
                gpio_set_out = 1'b1;
            end

            // x24 write: (x26 & x24) -> a `1` in x24 will make corresponding gpio pin an output
            5'd24: begin
                gpio_data_out = 32'hffffffff;
                gpio_mask_out = masked_gpio_set;
                gpio_set_oe = 1'b1;
            end

            // x25 write: (x26 & x25) -> a `1` in x25 will make corresponding gpio pin an input
            5'd25: begin
                gpio_data_out = 32'b0;
                gpio_mask_out = masked_gpio_set;
                gpio_set_oe = 1'b1;
            end

            5'd28: event_flags_set = femto_rd_wdata[23:0];
            5'd29: event_flags_clr = femto_rd_wdata[23:0];

            default: ;
        endcase
    end

    assign fifo_wdata = femto_rd_wdata;
    assign fifo_rd = {femto_rs1_id == 5'd16, femto_rs1_id == 5'd17, femto_rs1_id == 5'd18, femto_rs1_id == 5'd19} |
                     {femto_rs2_id == 5'd16, femto_rs2_id == 5'd17, femto_rs2_id == 5'd18, femto_rs2_id == 5'd19};

endmodule
