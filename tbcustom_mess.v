//======================================================================
// File: tb_sha256.v
//======================================================================
`timescale 1ns/1ps
`default_nettype none

module tbcustom_mess();

  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------
  parameter DEBUG = 0;
  // Clock settings for High Frequency simulation (~93MHz)
  parameter CLK_HALF_PERIOD = 5.66;
  parameter CLK_PERIOD = 2 * CLK_HALF_PERIOD;

  parameter ADDR_CTRL        = 8'h08;
  parameter CTRL_INIT_VALUE  = 8'h01;
  parameter CTRL_NEXT_VALUE  = 8'h02;
  parameter CTRL_MODE_VALUE  = 8'h04;

  parameter ADDR_STATUS      = 8'h09;
  parameter STATUS_READY_BIT = 0;
  parameter STATUS_VALID_BIT = 1;

  parameter ADDR_BLOCK0    = 8'h10;
  parameter ADDR_BLOCK1    = 8'h11;
  parameter ADDR_BLOCK2    = 8'h12;
  parameter ADDR_BLOCK3    = 8'h13;
  parameter ADDR_BLOCK4    = 8'h14;
  parameter ADDR_BLOCK5    = 8'h15;
  parameter ADDR_BLOCK6    = 8'h16;
  parameter ADDR_BLOCK7    = 8'h17;
  parameter ADDR_BLOCK8    = 8'h18;
  parameter ADDR_BLOCK9    = 8'h19;
  parameter ADDR_BLOCK10   = 8'h1a;
  parameter ADDR_BLOCK11   = 8'h1b;
  parameter ADDR_BLOCK12   = 8'h1c;
  parameter ADDR_BLOCK13   = 8'h1d;
  parameter ADDR_BLOCK14   = 8'h1e;
  parameter ADDR_BLOCK15   = 8'h1f;

  parameter ADDR_DIGEST0   = 8'h20;
  parameter ADDR_DIGEST1   = 8'h21;
  parameter ADDR_DIGEST2   = 8'h22;
  parameter ADDR_DIGEST3   = 8'h23;
  parameter ADDR_DIGEST4   = 8'h24;
  parameter ADDR_DIGEST5   = 8'h25;
  parameter ADDR_DIGEST6   = 8'h26;
  parameter ADDR_DIGEST7   = 8'h27;

  //----------------------------------------------------------------
  // Register and Wire declarations.
  //----------------------------------------------------------------
  reg [31 : 0] cycle_ctr;
  reg [31 : 0] error_ctr;
  reg [31 : 0] tc_ctr;

  reg           tb_clk;
  reg           tb_reset_n;
  reg           tb_cs;
  reg           tb_we;
  reg [7 : 0]   tb_address;
  reg [31 : 0]  tb_write_data;
  wire [31 : 0] tb_read_data;

  reg [31 : 0]  read_data;
  reg [255 : 0] digest_data;

  //----------------------------------------------------------------
  // Device Under Test.
  //----------------------------------------------------------------
  SHA256 dut(
             .clk(tb_clk),
             .reset_n(tb_reset_n),
             .cs(tb_cs),
             .we(tb_we),
             .address(tb_address),
             .write_data(tb_write_data),
             .read_data(tb_read_data)
            );

  //----------------------------------------------------------------
  // clk_gen
  //----------------------------------------------------------------
  always #CLK_HALF_PERIOD tb_clk = !tb_clk;

  //----------------------------------------------------------------
  // sys_monitor
  //----------------------------------------------------------------
  always @(posedge tb_clk) cycle_ctr <= cycle_ctr + 1;

  //----------------------------------------------------------------
  // reset_dut()
  //----------------------------------------------------------------
  task reset_dut;
    begin
      $display("*** Toggle reset.");
      tb_reset_n = 0;
      @(posedge tb_clk);
      @(posedge tb_clk);
      @(negedge tb_clk); // Release reset at negedge
      tb_reset_n = 1;
    end
  endtask

  //----------------------------------------------------------------
  // init_sim()
  //----------------------------------------------------------------
  task init_sim;
    begin
      cycle_ctr = 32'h0;
      error_ctr = 32'h0;
      tc_ctr = 32'h0;
      tb_clk = 0;
      tb_reset_n = 0;
      tb_cs = 0;
      tb_we = 0;
      tb_address = 8'h0;
      tb_write_data = 32'h0;
    end
  endtask

  //----------------------------------------------------------------
  // display_test_result()
  //----------------------------------------------------------------
  task display_test_result;
    begin
      if (error_ctr == 0)
        $display("*** All %02d test cases completed successfully.", tc_ctr);
      else begin
        $display("*** %02d test cases completed.", tc_ctr);
        $display("*** %02d errors detected during testing.", error_ctr);
      end
    end
  endtask

  //----------------------------------------------------------------
  // write_word()
  //----------------------------------------------------------------
  task write_word(input [7 : 0]  address,
                  input [31 : 0] word);
    begin
      if (DEBUG) $display("*** Writing 0x%08x to 0x%02x.", word, address);

      // Setup
      @(negedge tb_clk);
      tb_address = address;
      tb_write_data = word;
      tb_cs = 1;
      tb_we = 1;
      
      // Hold
      @(negedge tb_clk);

      // Release
      tb_cs = 0;
      tb_we = 0;
      tb_address = 8'h00;
      tb_write_data = 32'h00;
    end
  endtask

  //----------------------------------------------------------------
  // read_word() - Robust Negedge Sampling
  //----------------------------------------------------------------
  task read_word(input [7 : 0]  address);
    begin
      // Setup 
      @(negedge tb_clk); 
      tb_address = address;
      tb_cs = 1;
      tb_we = 0;
      
      // 2. Wait for DUT response (Passes 1 posedge)
      // 3. Sample at next Negedge
      @(negedge tb_clk);
      read_data = tb_read_data; 
      
      // 4. Release
      tb_cs = 0;
      tb_address = 8'h00;

      if (DEBUG) $display("*** Reading 0x%08x from 0x%02x.", read_data, address);
    end
  endtask

  //----------------------------------------------------------------
  // wait_ready() - [FIXED HERE]
  // Adds delay to ensure Core goes BUSY before we check for READY
  //----------------------------------------------------------------
  task wait_ready;
    begin
     
      repeat (2) @(posedge tb_clk);

      read_word(ADDR_STATUS);
      while ((read_data & (1<<STATUS_READY_BIT)) == 0) 
        begin
          read_word(ADDR_STATUS);
        end
        
      // Chờ thêm 1 nhịp sau khi Ready để đảm bảo Digest Output đã ổn định
      @(posedge tb_clk); 
    end
  endtask

  //----------------------------------------------------------------
  // write_block()
  //----------------------------------------------------------------
  task write_block(input [511 : 0] block);
    begin
      write_word(ADDR_BLOCK0,  block[511 : 480]);
      write_word(ADDR_BLOCK1,  block[479 : 448]);
      write_word(ADDR_BLOCK2,  block[447 : 416]);
      write_word(ADDR_BLOCK3,  block[415 : 384]);
      write_word(ADDR_BLOCK4,  block[383 : 352]);
      write_word(ADDR_BLOCK5,  block[351 : 320]);
      write_word(ADDR_BLOCK6,  block[319 : 288]);
      write_word(ADDR_BLOCK7,  block[287 : 256]);
      write_word(ADDR_BLOCK8,  block[255 : 224]);
      write_word(ADDR_BLOCK9,  block[223 : 192]);
      write_word(ADDR_BLOCK10, block[191 : 160]);
      write_word(ADDR_BLOCK11, block[159 : 128]);
      write_word(ADDR_BLOCK12, block[127 :  96]);
      write_word(ADDR_BLOCK13, block[95  :  64]);
      write_word(ADDR_BLOCK14, block[63  :  32]);
      write_word(ADDR_BLOCK15, block[31  :   0]);
    end
  endtask

  //----------------------------------------------------------------
  // read_digest()
  //----------------------------------------------------------------
  task read_digest;
    begin
      read_word(ADDR_DIGEST0); digest_data[255 : 224] = read_data;
      read_word(ADDR_DIGEST1); digest_data[223 : 192] = read_data;
      read_word(ADDR_DIGEST2); digest_data[191 : 160] = read_data;
      read_word(ADDR_DIGEST3); digest_data[159 : 128] = read_data;
      read_word(ADDR_DIGEST4); digest_data[127 :  96] = read_data;
      read_word(ADDR_DIGEST5); digest_data[95  :  64] = read_data;
      read_word(ADDR_DIGEST6); digest_data[63  :  32] = read_data;
      read_word(ADDR_DIGEST7); digest_data[31  :   0] = read_data;
    end
  endtask

  //----------------------------------------------------------------
  // issue_test()
  //----------------------------------------------------------------
  task issue_test;
    reg [511 : 0] b[0:8];
    reg [255 : 0] expected;
    integer i;
    begin
      //$display("Running test for 9 block issue.");
      tc_ctr = tc_ctr + 1;
			b[0] = 512'h5472756f6e672064616920686f6320636f6e67206e6768652074686f6e672074696e800000000000000000000000000000000000000000000000000000000110; 

//			b[1] = 512'h656e657261746564206576657279206461792e496e207468652061726561206f6620496f542028496e7465726e6574206f66205468696e6773292c206d6f7265;
//
	//		b[2] = 512'h20616e64206d6f726520646174612069732067656e657261746564206576657279206461792e496e207468652061726561206f6620496f542028496e7465726e;

		//	b[3] = 512'h6574206f66205468696e6773292c206d6f726520616e64206d6f726520646174612069732067656e657261746564206576657279206461792e80000000000000;

			//b[4] = 512'h000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007c8;

			// Expected SHA-256 hash:
			expected = 256'hf2fd31f225073241086d1427cc0c6251a5ee559fd444be2c408e06dabff07060;
      for (i = 0; i < 1; i = i + 1) begin
          write_block(b[i]);
          if (i == 0) write_word(ADDR_CTRL, (CTRL_MODE_VALUE + CTRL_INIT_VALUE));
          else        write_word(ADDR_CTRL, (CTRL_MODE_VALUE + CTRL_NEXT_VALUE));
          
          wait_ready();
      end
		
      read_digest();
      if (digest_data == expected) $display("Digest ok.");
      else begin
          $display("ERROR in digest");
          $display("Expected: 0x%064x", expected);
          $display("Got:      0x%064x", digest_data);
          error_ctr = error_ctr + 1;
      end
		@(posedge tb_clk); 
		@(posedge tb_clk); 
		@(posedge tb_clk); 
		
    end
  endtask

  //----------------------------------------------------------------
  // MAIN
  //----------------------------------------------------------------
  initial begin
      $display("   -- Testbench for sha256 started --");
      $display("Use %0.2f MHz clock", 1000.0/CLK_PERIOD);
		init_sim();
      reset_dut();
      issue_test();
      
      
      display_test_result();
      $display("   -- Testbench for sha256 done. --");
      $finish;
  end

endmodule