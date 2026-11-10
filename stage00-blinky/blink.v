// stage00 — blinky. One concept: a counter divides the clock down
// to human speed and the top bit drives an LED.
module blink #(
    parameter WIDTH = 26          // 2^26 / 25MHz ~ 2.7s period
)(
    input  wire        clk_25mhz,   // ULX3S pin names, per common/ulx3s_v20.lpf
    output wire [7:0]  led
);
    reg [WIDTH-1:0] count = 0;
    always @(posedge clk_25mhz)
        count <= count + 1'b1;
    assign led = count[WIDTH-1 -: 8];   // top 8 bits: binary odometer
endmodule
