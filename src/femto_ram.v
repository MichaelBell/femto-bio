/* Copyright 2026 (c) Michael Bell
   SPDX-License-Identifier: BSD-3-Clause
   
   RAM module for Femto BIO CPU */

`default_nettype none

// 16-bit wide RAM with single read/write port, byte enables on write
module internal_ram #(parameter RAM_WIDTH=10) (
    `ifdef USE_POWER_PINS
    inout  wire VDD,
    inout  wire VSS,
    `endif
    input clk,
    input rst_n,
    input [1:0] wen,
    input [RAM_WIDTH-2:0] addr,
    input [15:0] data_in,

    output [15:0] data_out
);

`ifdef SYNTH_FPGA
    reg [15:0] ram [0:(1<<(RAM_WIDTH-1))-1];

`ifdef INIT_FILENAME
    parameter INIT_FILE = `INIT_FILENAME;
    initial begin
        $readmemh(INIT_FILE, ram);
    end
`endif

    reg [15:0] data_out_r;
    always @(posedge clk) begin
        if (wen[0]) ram[addr][7:0] <= data_in[7:0];
        if (wen[1]) ram[addr][15:8] <= data_in[15:8];
        data_out_r <= ram[addr];
    end

    assign data_out = data_out_r;

`else

    wire cen;
    gf180mcu_as_sc_mcu7t3v3__dlybuff_2 i_cen_delay (
        `ifdef USE_POWER_PINS
        .VDD  (VDD),
        .VSS  (VSS),
        `endif
        
        .A(!rst_n), .Y(cen));

    gf180mcu_ocd_ip_sram__sram512x8m8wm1 sram_0 (
        `ifdef USE_POWER_PINS
        .VDD  (VDD),
        .VSS  (VSS),
        `endif

        .CLK  (clk),
        .CEN  (cen),
        .GWEN (~wen[0]),
        .WEN  (8'b0),
        .A    (addr),
        .D    (data_in[7:0]),
        .Q    (data_out[7:0])
    );

    gf180mcu_ocd_ip_sram__sram512x8m8wm1 sram_1 (
        `ifdef USE_POWER_PINS
        .VDD  (VDD),
        .VSS  (VSS),
        `endif

        .CLK  (clk),
        .CEN  (cen),
        .GWEN (~wen[1]),
        .WEN  (8'b0),
        .A    (addr),
        .D    (data_in[15:8]),
        .Q    (data_out[15:8])
    );

`endif

endmodule

// Wrapper module for the internal 16-bit wide RAM to provide a 32-bit interface suitable for the Femto BIO CPU.
// Normally reads and writes take 2 cycles, but if idle cycles follows an instruction read the next instruction 
// is cached so it can be fetched without additional wait.
// Inputs must remain constant while a transaction is in progress
module femto_ram #(parameter RAM_WIDTH=10) (
    `ifdef USE_POWER_PINS
    inout  wire VDD,
    inout  wire VSS,
    `endif

    input clk,
    input rst_n,

    input rstrb,    // High to request a read
    input rinstr,   // High on instruction fetch - in this case
                    // the data at addr + 4 is cached after this
                    // read completes so it is available for the 
                    // next instruction fetch

    input wstrb,    // High to request a write
    input [3:0] mask,  // Byte-enable mask for writes

    input [RAM_WIDTH-1:0] addr,  // Address, low 2 bits should be 0 for word (32-bit) accesses.
    input half,                 // High if accessing a half-word (16 bits), 
                                // in this case data_out has high and low halfs equal
                                // and address bit 1 controls which half word is read.

    output rbusy,      // High while a read is in progress
    output wbusy,      // High while a write is in progress
    
    input [31:0] data_in,
    output reg [31:0] data_out
);

    localparam STATE_IDLE               = 3'd0;
    localparam STATE_READ_LOW           = 3'd1;
    localparam STATE_READ_HIGH          = 3'd2;
    localparam STATE_PREFETCH_LOW       = 3'd3;
    localparam STATE_PREFETCH_HIGH      = 3'd4;
    localparam STATE_WRITE_HIGH         = 3'd5;

    reg [2:0] state;
    reg [15:0] read_low_data;

    reg cache_valid;
    reg [RAM_WIDTH-1:2] cache_addr;
    reg [31:0] cache_data;

    // TODO: Replace with latch
    reg [31:0] held_data_out;

    reg [1:0] ram_wen;
    reg [RAM_WIDTH-2:0] ram_addr;
    reg [15:0] ram_data_in;
    wire [15:0] ram_data_out;

    reg rstrb_next;
    reg wstrb_next;

    wire is_cache_addr = (addr[RAM_WIDTH-1:2] == cache_addr);
    wire cache_hit = rstrb && rinstr && !half && cache_valid && is_cache_addr;
    wire prefetch_hit = (rstrb || rstrb_next) && rinstr && !half && (state == STATE_PREFETCH_HIGH) && is_cache_addr;
    wire read_complete = (state == STATE_READ_HIGH) || (state == STATE_READ_LOW && half) ||
                         cache_hit || prefetch_hit;
    wire write_active = (state == STATE_WRITE_HIGH);

    assign rbusy = ((rstrb || rstrb_next) && !read_complete) || (state == STATE_READ_LOW && !half);
    assign wbusy = (wstrb || wstrb_next) || write_active;

    wire [RAM_WIDTH-2:0] low_ram_addr = {addr[RAM_WIDTH-1:2], 1'b0};
    wire [RAM_WIDTH-2:0] high_ram_addr = {addr[RAM_WIDTH-1:2], 1'b1};
    wire [RAM_WIDTH-2:0] half_ram_addr = addr[1] ? high_ram_addr : low_ram_addr;
    wire [RAM_WIDTH-1:2] next_cache_addr = addr[RAM_WIDTH-1:2] + 1;

    always @(*) begin
        ram_wen = 2'b00;
        ram_addr = addr[RAM_WIDTH-1:1];
        ram_data_in = data_in[15:0];
        data_out = held_data_out;

        if (cache_hit) begin
            data_out = cache_data;
        end else if (prefetch_hit) begin
            data_out = {ram_data_out, cache_data[15:0]};
        end else if (state == STATE_READ_LOW && half) begin
            data_out = {ram_data_out, ram_data_out};
        end else if (state == STATE_READ_HIGH) begin
            data_out = {ram_data_out, read_low_data};
        end

        case (state)
        STATE_IDLE: begin
            if (wstrb) begin
                if (|mask[1:0]) begin
                    ram_addr = low_ram_addr;
                    ram_wen = mask[1:0];
                    ram_data_in = data_in[15:0];
                end else begin
                    ram_addr = high_ram_addr;
                    ram_wen = mask[3:2];
                    ram_data_in = data_in[31:16];
                end
            end else if (cache_hit) begin
                ram_addr = {next_cache_addr, 1'b0};
            end
        end
        STATE_READ_LOW: begin
            ram_addr = high_ram_addr;
        end
        STATE_READ_HIGH: begin
            ram_addr = {cache_addr, 1'b0};
        end
        STATE_PREFETCH_LOW: begin
            if (!rstrb || !rinstr || is_cache_addr) begin
                ram_addr = {cache_addr, 1'b1};
            end 
        end
        STATE_PREFETCH_HIGH: begin
            if (wstrb || wstrb_next) begin
                if (|mask[1:0]) begin
                    ram_addr = low_ram_addr;
                    ram_wen = mask[1:0];
                    ram_data_in = data_in[15:0];
                end else begin
                    ram_addr = high_ram_addr;
                    ram_wen = mask[3:2];
                    ram_data_in = data_in[31:16];
                end
            end else if (prefetch_hit) begin
                ram_addr = {next_cache_addr, 1'b0};
            end
        end
        STATE_WRITE_HIGH: begin
            ram_addr = high_ram_addr;
            ram_wen = mask[3:2];
            ram_data_in = data_in[31:16];
        end
        default: begin
        end
        endcase
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            cache_valid <= 1'b0;
            cache_addr <= 0;
            read_low_data <= 16'd0;
            held_data_out <= 32'd0;
            rstrb_next <= 1'b0;
            wstrb_next <= 1'b0;
        end else begin
            rstrb_next <= 1'b0;
            wstrb_next <= 1'b0;

            case (state)
            STATE_IDLE: begin
                if (wstrb) begin
                    if (is_cache_addr) begin
                        cache_valid <= 1'b0;
                    end
                    if (|mask[1:0] && |mask[3:2]) begin
                        state <= STATE_WRITE_HIGH;
                    end
                end else if (cache_hit) begin
                    held_data_out <= cache_data;
                    if (rinstr) begin
                        state <= STATE_PREFETCH_LOW;
                        cache_addr <= next_cache_addr;
                        cache_valid <= 1'b0;
                    end
                end else if (rstrb) begin
                    state <= STATE_READ_LOW;
                    if (rinstr) begin
                        cache_addr <= next_cache_addr;
                        cache_valid <= 1'b0;
                    end
                end
            end
            STATE_READ_LOW: begin
                if (half) begin
                    held_data_out <= {ram_data_out, ram_data_out};
                    state <= STATE_IDLE;
                end else begin
                    read_low_data <= ram_data_out;
                    state <= STATE_READ_HIGH;
                end
            end
            STATE_READ_HIGH: begin
                held_data_out <= {ram_data_out, read_low_data};
                if (rinstr) begin
                    state <= STATE_PREFETCH_LOW;
                end else begin
                    state <= STATE_IDLE;
                end
            end
            STATE_PREFETCH_LOW: begin
                cache_data[15:0] <= ram_data_out;
                state <= STATE_PREFETCH_HIGH;
                wstrb_next <= wstrb;
                if (rstrb && rinstr && !is_cache_addr) begin
                    cache_addr <= next_cache_addr;
                    cache_valid <= 1'b0;
                    state <= STATE_READ_LOW;
                end else begin
                    rstrb_next <= rstrb;
                end
            end
            STATE_PREFETCH_HIGH: begin
                cache_valid <= 1'b1;
                cache_data[31:16] <= ram_data_out;
                if (prefetch_hit) begin
                    held_data_out <= {ram_data_out, cache_data[15:0]};
                    if (rinstr) begin
                        state <= STATE_PREFETCH_LOW;
                        cache_addr <= next_cache_addr;
                        cache_valid <= 1'b0;
                    end else begin
                        state <= STATE_IDLE;
                    end
                end else if (wstrb || wstrb_next) begin
                    if (is_cache_addr) begin
                        cache_valid <= 1'b0;
                    end
                    if (|mask[1:0] && |mask[3:2]) begin
                        state <= STATE_WRITE_HIGH;
                    end else begin
                        state <= STATE_IDLE;
                    end
                end else if (rstrb || rstrb_next) begin
                    if (rinstr) begin
                        cache_addr <= next_cache_addr;
                        cache_valid <= 1'b0;
                    end
                    state <= STATE_READ_LOW;
                end else begin
                    state <= STATE_IDLE;
                end
            end
            STATE_WRITE_HIGH: begin
                state <= STATE_IDLE;
            end
            default: begin
                state <= STATE_IDLE;
            end
            endcase
        end
    end

    internal_ram #(.RAM_WIDTH(RAM_WIDTH)) i_ram(
        `ifdef USE_POWER_PINS
        .VDD  (VDD),
        .VSS  (VSS),
        `endif

        .clk(clk),
        .rst_n(rst_n),
        .wen(ram_wen),
        .addr(ram_addr),
        .data_in(ram_data_in),
        .data_out(ram_data_out)
    );

endmodule
