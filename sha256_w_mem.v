// sha256_w_mem.v
`default_nettype none

module sha256_w_mem(
    input  wire        clk,
    input  wire        reset_n,
    input  wire [511:0] block,
    input  wire [5:0]   round,
    input  wire         init,
    input  wire         next,
    output wire [31:0]  w
);

  //----------------------------------------------------------------
  // Registers
  //----------------------------------------------------------------
  reg [31:0] w_mem [0:15];
  reg [31:0] w_mem00_new, w_mem01_new, w_mem02_new, w_mem03_new;
  reg [31:0] w_mem04_new, w_mem05_new, w_mem06_new, w_mem07_new;
  reg [31:0] w_mem08_new, w_mem09_new, w_mem10_new, w_mem11_new;
  reg [31:0] w_mem12_new, w_mem13_new, w_mem14_new, w_mem15_new;
  reg        w_mem_we;

  //----------------------------------------------------------------
  // Wires
  //----------------------------------------------------------------
  reg [31:0] w_tmp;
  reg [31:0] w_new;

  assign w = w_tmp;

  //----------------------------------------------------------------
  // CSA function
  //----------------------------------------------------------------
  function [63:0] csa3;
    input [31:0] a, b, c;
    reg [31:0] sum, carry;
    begin
      sum   = a ^ b ^ c;
      carry = (a & b) | (b & c) | (a & c);
      csa3  = {carry, sum};
    end
  endfunction

  //----------------------------------------------------------------
  // reg_update
  //----------------------------------------------------------------
  
  
  always @(posedge clk or negedge reset_n) begin: req_update
  integer i;
    if (!reset_n) begin
      for (i=0; i<16; i=i+1) w_mem[i] <= 32'h0;
    end else begin
      if (w_mem_we) begin
        w_mem[0]  <= w_mem00_new;
        w_mem[1]  <= w_mem01_new;
        w_mem[2]  <= w_mem02_new;
        w_mem[3]  <= w_mem03_new;
        w_mem[4]  <= w_mem04_new;
        w_mem[5]  <= w_mem05_new;
        w_mem[6]  <= w_mem06_new;
        w_mem[7]  <= w_mem07_new;
        w_mem[8]  <= w_mem08_new;
        w_mem[9]  <= w_mem09_new;
        w_mem[10] <= w_mem10_new;
        w_mem[11] <= w_mem11_new;
        w_mem[12] <= w_mem12_new;
        w_mem[13] <= w_mem13_new;
        w_mem[14] <= w_mem14_new;
        w_mem[15] <= w_mem15_new;
      end
    end
  end

  //----------------------------------------------------------------
  // select_w
  //----------------------------------------------------------------
  always @* begin
    if (round < 16)
      w_tmp = w_mem[round[3:0]];
    else
      w_tmp = w_new;
  end

  //----------------------------------------------------------------
  // w_new_logic 
  //----------------------------------------------------------------
  reg [31:0] w_0, w_1, w_9, w_14;
  reg [31:0] d0, d1;
  reg [31:0] sum1, carry1, sum2, carry2;
  reg [63:0] csa_res;

  always @* begin
    // INIt
    w_mem00_new = 32'h0; w_mem01_new = 32'h0; w_mem02_new = 32'h0; w_mem03_new = 32'h0;
    w_mem04_new = 32'h0; w_mem05_new = 32'h0; w_mem06_new = 32'h0; w_mem07_new = 32'h0;
    w_mem08_new = 32'h0; w_mem09_new = 32'h0; w_mem10_new = 32'h0; w_mem11_new = 32'h0;
    w_mem12_new = 32'h0; w_mem13_new = 32'h0; w_mem14_new = 32'h0; w_mem15_new = 32'h0;
    w_mem_we = 0;
    w_new = 32'h0;

    // Load W 
    w_0  = w_mem[0];
    w_1  = w_mem[1];
    w_9  = w_mem[9];
    w_14 = w_mem[14];

    // Small sigma
    d0 = {w_1[6:0], w_1[31:7]} ^ {w_1[17:0], w_1[31:18]} ^ {3'b0, w_1[31:3]};
    d1 = {w_14[16:0], w_14[31:17]} ^ {w_14[18:0], w_14[31:19]} ^ {10'b0, w_14[31:10]};

	csa_res = csa3(d1, w_9, d0);
	sum1   = csa_res[31:0];
	carry1 = csa_res[63:32] << 1;   // shift 1 bit 

	csa_res = csa3(sum1, carry1, w_0);
	sum2   = csa_res[31:0];
	carry2 = csa_res[63:32] << 1; // shift 1 bit 

	w_new = sum2 + carry2;
		
    // init
    if (init) begin
      w_mem00_new = block[511:480]; w_mem01_new = block[479:448];
      w_mem02_new = block[447:416]; w_mem03_new = block[415:384];
      w_mem04_new = block[383:352]; w_mem05_new = block[351:320];
      w_mem06_new = block[319:288]; w_mem07_new = block[287:256];
      w_mem08_new = block[255:224]; w_mem09_new = block[223:192];
      w_mem10_new = block[191:160]; w_mem11_new = block[159:128];
      w_mem12_new = block[127:96];  w_mem13_new = block[95:64];
      w_mem14_new = block[63:32];   w_mem15_new = block[31:0];
      w_mem_we = 1;
    end

    // shift W
    if (next && (round > 15)) begin
      w_mem00_new = w_mem[1];  w_mem01_new = w_mem[2];  w_mem02_new = w_mem[3];  w_mem03_new = w_mem[4];
      w_mem04_new = w_mem[5];  w_mem05_new = w_mem[6];  w_mem06_new = w_mem[7];  w_mem07_new = w_mem[8];
      w_mem08_new = w_mem[9];  w_mem09_new = w_mem[10]; w_mem10_new = w_mem[11]; w_mem11_new = w_mem[12];
      w_mem12_new = w_mem[13]; w_mem13_new = w_mem[14]; w_mem14_new = w_mem[15]; w_mem15_new = w_new;
      w_mem_we = 1;
    end
  end

endmodule

