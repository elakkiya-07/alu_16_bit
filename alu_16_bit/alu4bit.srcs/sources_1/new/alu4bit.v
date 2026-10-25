`timescale 1ns / 1ps

// 16-bit ALU
// sel  operation
// 0000 add
// 0001 add with carry
// 0010 sub
// 0011 sub with borrow
// 0100 and
// 0101 or
// 0110 xor
// 0111 not a
// 1000 shift left logical
// 1001 shift right logical
// 1010 shift right arithmetic
// 1011 rotate left
// 1100 rotate right
// 1101 set less than (signed)
// 1110 set less than (unsigned)
// 1111 pass b
//
// shift amount = b[3:0]
// for sub, carry = 1 means borrow (a < b)

module alu16(a, b, sel, cin, y, carry, overflow, negative, zero);
input [15:0] a, b;
input [3:0] sel;
input cin;
output reg [15:0] y;
output reg carry;
output reg overflow;
output negative;
output zero;

reg [16:0] temp;     // one extra bit to catch carry / shifted out bit
wire [3:0] shift;
assign shift = b[3:0];

always @(*) begin
    y = 16'd0;
    carry = 1'b0;
    overflow = 1'b0;
    temp = 17'd0;

    case (sel)
    4'b0000: begin  // add
        temp = a + b;
        y = temp[15:0];
        carry = temp[16];
        if (a[15] == b[15] && y[15] != a[15])
            overflow = 1'b1;
    end

    4'b0001: begin  // add with carry
        temp = a + b + cin;
        y = temp[15:0];
        carry = temp[16];
        if (a[15] == b[15] && y[15] != a[15])
            overflow = 1'b1;
    end

    4'b0010: begin  // sub
        temp = a - b;
        y = temp[15:0];
        carry = temp[16];
        if (a[15] != b[15] && y[15] != a[15])
            overflow = 1'b1;
    end

    4'b0011: begin  // sub with borrow
        temp = a - b - cin;
        y = temp[15:0];
        carry = temp[16];
        if (a[15] != b[15] && y[15] != a[15])
            overflow = 1'b1;
    end

    4'b0100: y = a & b;
    4'b0101: y = a | b;
    4'b0110: y = a ^ b;
    4'b0111: y = ~a;

    4'b1000: begin  // shift left logical
        temp = a << shift;
        y = temp[15:0];
        carry = temp[16];
    end

    4'b1001: begin  // shift right logical
        temp = {a, 1'b0} >> shift;
        y = temp[16:1];
        carry = temp[0];
    end

    4'b1010: begin  // shift right arithmetic
        temp = $signed({a, 1'b0}) >>> shift;
        y = temp[16:1];
        carry = temp[0];
    end

    4'b1011: begin  // rotate left
        y = (a << shift) | (a >> (16 - shift));
        if (shift != 0)
            carry = y[0];
    end

    4'b1100: begin  // rotate right
        y = (a >> shift) | (a << (16 - shift));
        if (shift != 0)
            carry = y[15];
    end

    4'b1101: begin  // signed compare
        if ($signed(a) < $signed(b))
            y = 16'd1;
        else
            y = 16'd0;
    end

    4'b1110: begin  // unsigned compare
        if (a < b)
            y = 16'd1;
        else
            y = 16'd0;
    end

    4'b1111: y = b;

    default: y = 16'd0;
    endcase
end

assign zero = (y == 16'd0);
assign negative = y[15];

endmodule