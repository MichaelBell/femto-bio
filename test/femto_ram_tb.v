`default_nettype none

module tb ();

    wire clk;
    wire rst_n;

    wire rstrb;
    wire rinstr;

    wire wstrb;
    wire [3:0] mask;

    wire [31:0] addr;
    wire half;

    wire rbusy;
    wire wbusy;

    wire [31:0] data_in;
    wire [31:0] data_out;

    femto_ram dut (
        .clk(clk),
        .rst_n(rst_n),
        .rstrb(rstrb),
        .rinstr(rinstr),
        .wstrb(wstrb),
        .mask(mask),
        .addr(addr),
        .half(half),
        .rbusy(rbusy),
        .wbusy(wbusy),
        .data_in(data_in),
        .data_out(data_out)
    );

endmodule