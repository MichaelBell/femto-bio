`default_nettype none

module tb ();

    wire clk;
    wire rst_n;

    wire [31:0] gpio_out;
    wire [31:0] gpio_oe;
    wire [31:0] gpio_in;
    
    femto_bio dut (
        .clk(clk),
        .rst_n(rst_n),
        .gpio_out(gpio_out),
        .gpio_oe(gpio_oe),
        .gpio_in(gpio_in)
    );

endmodule