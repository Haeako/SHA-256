// sha256_core.v
`default_nettype none

module core(
    input  wire           clk,
    input  wire           reset_n,

    input  wire           init,
    input  wire           next,

    input  wire [511:0]   block,

    output wire           ready,
    output wire [255:0]   digest,
    output wire           digest_valid
  );


  //Begin Local params
  localparam SHA256_H0_0 = 32'h6a09e667;
  localparam SHA256_H0_1 = 32'hbb67ae85;
  localparam SHA256_H0_2 = 32'h3c6ef372;
  localparam SHA256_H0_3 = 32'ha54ff53a;
  localparam SHA256_H0_4 = 32'h510e527f;
  localparam SHA256_H0_5 = 32'h9b05688c;
  localparam SHA256_H0_6 = 32'h1f83d9ab;
  localparam SHA256_H0_7 = 32'h5be0cd19;

  // rounds 0..63 -> last index 63
  localparam SHA256_ROUNDS = 6'd63;

  // Control FSM states
  localparam CTRL_IDLE   = 2'd0; // ready for new block
  localparam CTRL_ROUNDS = 2'd1; // processing rounds
  localparam CTRL_DONE   = 2'd2; // digest valid
  //End Local params


  // Registers

  reg [31:0] a_reg, a_new;
  reg [31:0] b_reg, b_new;
  reg [31:0] c_reg, c_new;
  reg [31:0] d_reg, d_new;
  reg [31:0] e_reg, e_new;
  reg [31:0] f_reg, f_new;
  reg [31:0] g_reg, g_new;
  reg [31:0] h_reg, h_new;
  reg        a_h_we;        // write enable for a-h registers

  reg [31:0] H0_reg, H0_new;
  reg [31:0] H1_reg, H1_new;
  reg [31:0] H2_reg, H2_new;
  reg [31:0] H3_reg, H3_new;
  reg [31:0] H4_reg, H4_new;
  reg [31:0] H5_reg, H5_new;
  reg [31:0] H6_reg, H6_new;
  reg [31:0] H7_reg, H7_new;
  reg        H_we;          // write enable for H0-H7 registers  

  reg [5:0]  t_ctr_reg, t_ctr_new;
  reg        t_ctr_we;
  reg        t_ctr_inc;
  reg        t_ctr_rst;

  reg        digest_valid_reg;
  reg        digest_valid_new;
  reg        digest_valid_we;

  reg [1:0]  sha256_ctrl_reg, sha256_ctrl_new;
  reg        sha256_ctrl_we;


  // Internal signals

  reg        digest_init;
  reg        digest_update;

  reg        state_init;
  reg        state_update;

  reg        first_block;

  reg        ready_flag;

  reg [31:0] t1;
  reg [31:0] t2;

  wire [31:0] k_data;

  reg        w_init;
  reg        w_next;
  reg [5:0]  w_round;
  wire [31:0] w_data;


// Function helpers: rotr, shr, big/small sigma, ch, maj

  // Big Sigma 0
  function [31:0] big_sigma0 (
	  input [31:0] x
  );
    begin
      big_sigma0 = ({x[1:0],  x[31:2]}) ^   // ROTR 2
        ({x[12:0], x[31:13]}) ^  // ROTR 13
        ({x[21:0], x[31:22]});   // ROTR 22
    end
  endfunction
  
  // Big Sigma 1
  function [31:0] big_sigma1 (
    input [31:0] x
  );
    begin
      big_sigma1 =
        ({x[5:0],  x[31:6]}) ^   // ROTR 6
        ({x[10:0], x[31:11]}) ^  // ROTR 11
        ({x[24:0], x[31:25]});   // ROTR 25
    end
  endfunction

  // Choice
  function [31:0] ch(input [31:0] x, input [31:0] y, input [31:0] z);
    ch = (x & y) ^ ((~x) & z);
  endfunction

  // Majority
  function [31:0] maj(input [31:0] x, input [31:0] y, input [31:0] z);
    maj = (x & y) ^ (x & z) ^ (y & z);
  endfunction

  //----------------------------------------------------------------
  // CSA (Carry-Save Adder) Helper Functions
  // Optimizes multi-operand addition by reducing critical path
  //----------------------------------------------------------------
  
  // 3-input CSA: Produces sum and carry outputs
  function [63:0] csa3;
    input [31:0] a, b, c;
    reg [31:0] sum, carry;
  begin
    sum = a ^ b ^ c;                      // 3-input XOR for sum bits
    carry = (a & b) | (b & c) | (a & c);  // Majority function for carry
    csa3 = {carry, sum};                  // Return {carry[31:0], sum[31:0]}
  end
  endfunction

  // CSA wires for T1 calculation
  wire [31:0] t1_csa1_sum, t1_csa1_carry;
  wire [31:0] t1_csa2_sum, t1_csa2_carry;
  wire [31:0] t1_csa3_sum, t1_csa3_carry;
  wire [31:0] t1_final_sum;


  // Module instantiations (k constants and w memory)

  sha256_k_constants k_constants_inst(
    .round (t_ctr_reg),
    .K     (k_data)
  );

  sha256_w_mem w_mem_inst(
    .clk     (clk),
    .reset_n (reset_n),
    .block   (block),
    .round   (t_ctr_reg),
    .init    (w_init),
    .next    (w_next),
    .w       (w_data)
  );


  // Output assignments

  assign ready = ready_flag;
  assign digest = {H0_reg, H1_reg, H2_reg, H3_reg, H4_reg, H5_reg, H6_reg, H7_reg};
  assign digest_valid = digest_valid_reg;


  // Register update (sequential)

  always @(posedge clk or negedge reset_n) begin : reg_update
    if (!reset_n) begin
      a_reg            <= 32'h0;
      b_reg            <= 32'h0;
      c_reg            <= 32'h0;
      d_reg            <= 32'h0;
      e_reg            <= 32'h0;
      f_reg            <= 32'h0;
      g_reg            <= 32'h0;
      h_reg            <= 32'h0;
      H0_reg           <= 32'h0;
      H1_reg           <= 32'h0;
      H2_reg           <= 32'h0;
      H3_reg           <= 32'h0;
      H4_reg           <= 32'h0;
      H5_reg           <= 32'h0;
      H6_reg           <= 32'h0;
      H7_reg           <= 32'h0;
      digest_valid_reg <= 1'b0;
      t_ctr_reg        <= 6'h0;
      sha256_ctrl_reg  <= CTRL_IDLE;
    end
    else begin
      if (a_h_we) begin
        a_reg <= a_new;
        b_reg <= b_new;
        c_reg <= c_new;
        d_reg <= d_new;
        e_reg <= e_new;
        f_reg <= f_new;
        g_reg <= g_new;
        h_reg <= h_new;
      end

      if (H_we) begin
        H0_reg <= H0_new;
        H1_reg <= H1_new;
        H2_reg <= H2_new;
        H3_reg <= H3_new;
        H4_reg <= H4_new;
        H5_reg <= H5_new;
        H6_reg <= H6_new;
        H7_reg <= H7_new;
      end

      if (t_ctr_we)
        t_ctr_reg <= t_ctr_new;

      if (digest_valid_we)
        digest_valid_reg <= digest_valid_new;

      if (sha256_ctrl_we)
        sha256_ctrl_reg <= sha256_ctrl_new;
    end
  end // reg_update


  // Digest logic (init/update)

  always @* begin : digest_logic
    H0_new = 32'h0;
    H1_new = 32'h0;
    H2_new = 32'h0;
    H3_new = 32'h0;
    H4_new = 32'h0;
    H5_new = 32'h0;
    H6_new = 32'h0;
    H7_new = 32'h0;
    H_we   = 1'b0;

    if (digest_init) begin
      H_we = 1'b1;
      H0_new = SHA256_H0_0;
      H1_new = SHA256_H0_1;
      H2_new = SHA256_H0_2;
      H3_new = SHA256_H0_3;
      H4_new = SHA256_H0_4;
      H5_new = SHA256_H0_5;
      H6_new = SHA256_H0_6;
      H7_new = SHA256_H0_7;
 
    end

    if (digest_update) begin
      H0_new = H0_reg + a_reg;
      H1_new = H1_reg + b_reg;
      H2_new = H2_reg + c_reg;
      H3_new = H3_reg + d_reg;
      H4_new = H4_reg + e_reg;
      H5_new = H5_reg + f_reg;
      H6_new = H6_reg + g_reg;
      H7_new = H7_reg + h_reg;
      H_we = 1'b1;
    end
  end // digest_logic


  // t1 logic - CSA optimized
  // Original: t1 = h + Σ1(e) + Ch(e,f,g) + W + K
  // Using CSA tree to reduce critical path from ~6ns to ~2.5ns
  //
  // CSA Tree Structure:
  //   Level 1: CSA(h, Σ1(e), Ch(e,f,g)) -> {carry1, sum1}
  //   Level 2: CSA(sum1, W, K) -> {carry2, sum2}
  //   Level 3: CSA(sum2, carry1<<1, carry2<<1) -> {carry3, sum3}
  //   Final:   CPA(sum3 + carry3<<1) -> t1

  // Intermediate values
  reg [31:0] t1_sum1_val;
  reg [31:0] t1_chv_val;
  reg [63:0] t1_csa_result;

  always @* begin : t1_logic
    t1_sum1_val = big_sigma1(e_reg);
    t1_chv_val  = ch(e_reg, f_reg, g_reg);
  end // t1_logic

  // CSA Level 1: Add h + Σ1(e) + Ch(e,f,g)
  assign {t1_csa1_carry, t1_csa1_sum} = csa3(h_reg, t1_sum1_val, t1_chv_val);

  // CSA Level 2: Add w_data + k_data + csa1_sum
  assign {t1_csa2_carry, t1_csa2_sum} = csa3(w_data, k_data, t1_csa1_sum);

  // CSA Level 3: Add csa2_sum + csa1_carry<<1 + csa2_carry<<1
  assign {t1_csa3_carry, t1_csa3_sum} = csa3(t1_csa2_sum, 
                                             {t1_csa1_carry[30:0], 1'b0}, 
                                             {t1_csa2_carry[30:0], 1'b0});

  // Final Carry-Propagate Adder: Convert CSA result to normal binary
  assign t1_final_sum = t1_csa3_sum + {t1_csa3_carry[30:0], 1'b0};
  
  // Assign to t1 register
  always @* begin : t1_assign
    t1 = t1_final_sum;
  end // t1_assign


  // t2 logic

  always @* begin : t2_logic
    reg [31:0] sum0;
    reg [31:0] majv;

    sum0 = big_sigma0(a_reg);
    majv = maj(a_reg, b_reg, c_reg);

    t2 = sum0 + majv;
  end // t2_logic


  // State init / update logic

  always @* begin : state_logic
    a_new = 32'h0;
    b_new = 32'h0;
    c_new = 32'h0;
    d_new = 32'h0;
    e_new = 32'h0;
    f_new = 32'h0;
    g_new = 32'h0;
    h_new = 32'h0;
    a_h_we = 1'b0;

    if (state_init) begin
      a_h_we = 1'b1;
      if (first_block) begin
          a_new = SHA256_H0_0;
          b_new = SHA256_H0_1;
          c_new = SHA256_H0_2;
          d_new = SHA256_H0_3;
          e_new = SHA256_H0_4;
          f_new = SHA256_H0_5;
          g_new = SHA256_H0_6;
          h_new = SHA256_H0_7;
      end
      else begin
        a_new = H0_reg;
        b_new = H1_reg;
        c_new = H2_reg;
        d_new = H3_reg;
        e_new = H4_reg;
        f_new = H5_reg;
        g_new = H6_reg;
        h_new = H7_reg;
      end
    end

    if (state_update) begin
      a_new = t1 + t2;
      b_new = a_reg;
      c_new = b_reg;
      d_new = c_reg;
      e_new = d_reg + t1;
      f_new = e_reg;
      g_new = f_reg;
      h_new = g_reg;
      a_h_we = 1'b1;
    end
  end // state_logic


  // t_ctr update logic (combinational write enable)

  always @* begin : t_ctr
    t_ctr_new = 6'h0;
    t_ctr_we  = 1'b0;

    if (t_ctr_rst) begin
      t_ctr_new = 6'h0;
      t_ctr_we = 1'b1;
    end

    if (t_ctr_inc) begin
      t_ctr_new = t_ctr_reg + 1'b1;
      t_ctr_we = 1'b1;
    end
  end // t_ctr


  // Control FSM (sha256_ctrl_fsm)

  always @* begin : sha256_ctrl_fsm
    // default values
    digest_init      = 1'b0;
    digest_update    = 1'b0;

    state_init       = 1'b0;
    state_update     = 1'b0;

    first_block      = 1'b0;
    ready_flag       = 1'b0;

    w_init           = 1'b0;
    w_next           = 1'b0;

    t_ctr_inc        = 1'b0;
    t_ctr_rst        = 1'b0;

    digest_valid_new = 1'b0;
    digest_valid_we  = 1'b0;

    sha256_ctrl_new  = CTRL_IDLE;
    sha256_ctrl_we   = 1'b0;

    case (sha256_ctrl_reg)
      CTRL_IDLE: begin
        ready_flag = 1'b1;

        if (init) begin
          digest_init      = 1'b1;
          w_init           = 1'b1;
          state_init       = 1'b1;
          first_block      = 1'b1;
          t_ctr_rst        = 1'b1;
          digest_valid_new = 1'b0;
          digest_valid_we  = 1'b1;
          sha256_ctrl_new  = CTRL_ROUNDS;
          sha256_ctrl_we   = 1'b1;
        end

        if (next) begin
          t_ctr_rst        = 1'b1;
          w_init           = 1'b1;
          state_init       = 1'b1;
          digest_valid_new = 1'b0;
          digest_valid_we  = 1'b1;
          sha256_ctrl_new  = CTRL_ROUNDS;
          sha256_ctrl_we   = 1'b1;
        end
      end

      CTRL_ROUNDS: begin
        w_next       = 1'b1;
        state_update = 1'b1;
        t_ctr_inc    = 1'b1;

        if (t_ctr_reg == SHA256_ROUNDS) begin
          sha256_ctrl_new = CTRL_DONE;
          sha256_ctrl_we  = 1'b1;
        end
      end

      CTRL_DONE: begin
        digest_update    = 1'b1;
        digest_valid_new = 1'b1;
        digest_valid_we  = 1'b1;

        sha256_ctrl_new  = CTRL_IDLE;
        sha256_ctrl_we   = 1'b1;
      end

      default: begin
        // keep defaults
      end
    endcase
  end // sha256_ctrl_fsm

endmodule // sha256_core

`default_nettype wire
