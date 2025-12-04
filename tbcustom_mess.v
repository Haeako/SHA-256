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
      // [QUAN TRỌNG]
      // Chờ 1 nhịp clock để đảm bảo lệnh Start đã được xử lý 
      // và Status Register đã kịp cập nhật trạng thái BUSY (Ready=0).
      // Nếu không có dòng này, Testbench sẽ đọc ngay lập tức và thấy Ready=1 (cũ).
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

      b[0] = 512'h6b900001_496e2074_68652061_72656120_6f662049_6f542028_496e7465_726e6574_206f6620_5468696e_6773292c_206d6f72_6520616e_64206d6f_7265626f_6f6d2c20;
      b[1] = 512'h69742068_61732062_65656e20_6120756e_69766572_73616c20_636f6e73_656e7375_73207468_61742064_61746120_69732074_69732061_206e6577_20746563_686e6f6c;
      b[2] = 512'h6f677920_74686174_20696e74_65677261_74657320_64656365_6e747261_6c697a61_74696f6e_2c496e20_74686520_61726561_206f6620_496f5420_28496e74_65726e65;
      b[3] = 512'h74206f66_20546869_6e677329_2c206d6f_72652061_6e64206d_6f726562_6f6f6d2c_20697420_68617320_6265656e_20612075_6e697665_7273616c_20636f6e_73656e73;
      b[4] = 512'h75732074_68617420_64617461_20697320_74697320_61206e65_77207465_63686e6f_6c6f6779_20746861_7420696e_74656772_61746573_20646563_656e7472_616c697a;
      b[5] = 512'h6174696f_6e2c496e_20746865_20617265_61206f66_20496f54_2028496e_7465726e_6574206f_66205468_696e6773_292c206d_6f726520_616e6420_6d6f7265_626f6f6d;
      b[6] = 512'h2c206974_20686173_20626565_6e206120_756e6976_65727361_6c20636f_6e73656e_73757320_74686174_20646174_61206973_20746973_2061206e_65772074_6563686e;
      b[7] = 512'h6f6c6f67_79207468_61742069_6e746567_72617465_73206465_63656e74_72616c69_7a617469_6f6e2c49_6e207468_65206172_6561206f_6620496f_54202849_6e746572;
      b[8] = 512'h6e657420_6f662054_68696e67_73292c20_6d6f7265_20616e64_206d6f72_65800000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_000010e8;
      
      expected = 256'h7758a30bbdfc9cd92b284b05e9be9ca3d269d3d149e7e82ab4a9ed5e81fbcf9d;

      for (i = 0; i < 9; i = i + 1) begin
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