`default_nettype none

module tb ();

    wire clk;
    wire rst_n;

    wire [31:0] gpio_out;
    wire [31:0] gpio_oe;
    wire [31:0] gpio_in;

    wire uart_tx = gpio_out[3];

    wire [15:0] paddr;
    wire psel;
    wire penable;
    wire pwrite;
    wire [31:0] pwdata;
    wire [31:0] prdata;
    wire pready;
    
    femto_bio dut (
        .clk(clk),
        .rst_n(rst_n),
        .gpio_out(gpio_out),
        .gpio_oe(gpio_oe),
        .gpio_in(gpio_in),
        .paddr(paddr),
        .psel(psel),
        .penable(penable),
        .pwrite(pwrite),
        .pwdata(pwdata),
        .prdata(prdata),
        .pready(pready)
    );

endmodule