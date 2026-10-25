// testbench for alu16
// part 1: fixed edge cases with hand-worked answers
// part 2: random inputs checked against a simple model

`timescale 1ns/1ps

module tb_alu16;

reg [15:0] a, b;
reg [3:0] sel;
reg cin;
wire [15:0] y;
wire carry, overflow, negative, zero;

integer pass, fail, i, k;

// expected values
reg [15:0] exp_y;
reg exp_c, exp_v;
reg [16:0] t;
reg [15:0] r;

alu16 dut(a, b, sel, cin, y, carry, overflow, negative, zero);

// compare dut output with expected values
task check;
begin
    if (y === exp_y && carry === exp_c && overflow === exp_v &&
        zero === (exp_y == 16'd0) && negative === exp_y[15]) begin
        pass = pass + 1;
    end
    else begin
        fail = fail + 1;
        $display("FAIL sel=%b a=%h b=%h cin=%b | got y=%h c=%b v=%b n=%b z=%b | exp y=%h c=%b v=%b",
                 sel, a, b, cin, y, carry, overflow, negative, zero, exp_y, exp_c, exp_v);
    end
end
endtask

// apply one fixed test with hand-worked answer
task fixed_test;
input [3:0] s;
input [15:0] x, z;
input ci;
input [15:0] ey;
input ec, ev;
begin
    sel = s; a = x; b = z; cin = ci;
    exp_y = ey; exp_c = ec; exp_v = ev;
    #10;
    check;
end
endtask

// simple model: shifts are done one bit at a time with a loop,
// so it is written differently from the design
task model;
begin
    exp_y = 16'd0;
    exp_c = 1'b0;
    exp_v = 1'b0;
    r = a;

    case (sel)
    4'b0000: begin
        t = a + b;
        exp_y = t[15:0]; exp_c = t[16];
        exp_v = (a[15] == b[15]) && (exp_y[15] != a[15]);
    end
    4'b0001: begin
        t = a + b + cin;
        exp_y = t[15:0]; exp_c = t[16];
        exp_v = (a[15] == b[15]) && (exp_y[15] != a[15]);
    end
    4'b0010: begin
        exp_y = a - b;
        exp_c = (a < b);
        exp_v = (a[15] != b[15]) && (exp_y[15] != a[15]);
    end
    4'b0011: begin
        exp_y = a - b - cin;
        exp_c = (a < b + cin);      // b + cin can be 65536, compare in 32 bits
        exp_v = (a[15] != b[15]) && (exp_y[15] != a[15]);
    end
    4'b0100: exp_y = a & b;
    4'b0101: exp_y = a | b;
    4'b0110: exp_y = a ^ b;
    4'b0111: exp_y = ~a;
    4'b1000: begin
        for (k = 0; k < b[3:0]; k = k + 1) begin
            exp_c = r[15];
            r = {r[14:0], 1'b0};
        end
        exp_y = r;
    end
    4'b1001: begin
        for (k = 0; k < b[3:0]; k = k + 1) begin
            exp_c = r[0];
            r = {1'b0, r[15:1]};
        end
        exp_y = r;
    end
    4'b1010: begin
        for (k = 0; k < b[3:0]; k = k + 1) begin
            exp_c = r[0];
            r = {r[15], r[15:1]};
        end
        exp_y = r;
    end
    4'b1011: begin
        for (k = 0; k < b[3:0]; k = k + 1) begin
            r = {r[14:0], r[15]};
            exp_c = r[0];
        end
        exp_y = r;
    end
    4'b1100: begin
        for (k = 0; k < b[3:0]; k = k + 1) begin
            r = {r[0], r[15:1]};
            exp_c = r[15];
        end
        exp_y = r;
    end
    4'b1101: exp_y = ($signed(a) < $signed(b)) ? 16'd1 : 16'd0;
    4'b1110: exp_y = (a < b) ? 16'd1 : 16'd0;
    4'b1111: exp_y = b;
    endcase
end
endtask

initial begin
    $dumpfile("alu16.vcd");
    $dumpvars(0, tb_alu16);

    pass = 0;
    fail = 0;

    // ---------- part 1: fixed cases ----------
    //          sel      a         b        cin  y        c     v
    fixed_test(4'b0000, 16'h7FFF, 16'h0001, 0, 16'h8000, 1'b0, 1'b1); // add, signed overflow
    fixed_test(4'b0000, 16'hFFFF, 16'h0001, 0, 16'h0000, 1'b1, 1'b0); // add, carry and zero
    fixed_test(4'b0001, 16'hFFFF, 16'h0000, 1, 16'h0000, 1'b1, 1'b0); // add with carry
    fixed_test(4'b0010, 16'h8000, 16'h0001, 0, 16'h7FFF, 1'b0, 1'b1); // sub, signed overflow
    fixed_test(4'b0010, 16'h0005, 16'h0005, 0, 16'h0000, 1'b0, 1'b0); // sub, zero
    fixed_test(4'b0010, 16'h0001, 16'h0002, 0, 16'hFFFF, 1'b1, 1'b0); // sub, borrow
    fixed_test(4'b0011, 16'h0000, 16'h0000, 1, 16'hFFFF, 1'b1, 1'b0); // sub with borrow
    fixed_test(4'b0100, 16'hF0F0, 16'hFF00, 0, 16'hF000, 1'b0, 1'b0); // and
    fixed_test(4'b0101, 16'hF0F0, 16'h0F00, 0, 16'hFFF0, 1'b0, 1'b0); // or
    fixed_test(4'b0110, 16'hFFFF, 16'hFFFF, 0, 16'h0000, 1'b0, 1'b0); // xor
    fixed_test(4'b0111, 16'h00FF, 16'h0000, 0, 16'hFF00, 1'b0, 1'b0); // not
    fixed_test(4'b1000, 16'h8001, 16'h0001, 0, 16'h0002, 1'b1, 1'b0); // sll
    fixed_test(4'b1000, 16'h1234, 16'h0000, 0, 16'h1234, 1'b0, 1'b0); // sll by 0
    fixed_test(4'b1001, 16'h8001, 16'h0001, 0, 16'h4000, 1'b1, 1'b0); // srl
    fixed_test(4'b1010, 16'h8000, 16'h0004, 0, 16'hF800, 1'b0, 1'b0); // sra keeps sign
    fixed_test(4'b1010, 16'h8000, 16'h000F, 0, 16'hFFFF, 1'b0, 1'b0); // sra by 15
    fixed_test(4'b1011, 16'h8001, 16'h0001, 0, 16'h0003, 1'b1, 1'b0); // rol
    fixed_test(4'b1100, 16'h8001, 16'h0001, 0, 16'hC000, 1'b1, 1'b0); // ror
    fixed_test(4'b1101, 16'hFFFF, 16'h0001, 0, 16'h0001, 1'b0, 1'b0); // slt: -1 < 1
    fixed_test(4'b1110, 16'hFFFF, 16'h0001, 0, 16'h0000, 1'b0, 1'b0); // sltu: 65535 > 1
    fixed_test(4'b1111, 16'h0000, 16'hABCD, 0, 16'hABCD, 1'b0, 1'b0); // pass b

    $display("fixed tests done: pass=%0d fail=%0d", pass, fail);

    // ---------- part 2: random tests ----------
    for (i = 0; i < 5000; i = i + 1) begin
        a = $random;
        b = $random;
        cin = $random;
        sel = $random;
        #1;
        model;
        #9;
        check;
    end

    $display("all tests done: pass=%0d fail=%0d", pass, fail);
    if (fail == 0)
        $display("ALL TESTS PASSED");
    $finish;
end

endmodule