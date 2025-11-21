library verilog;
use verilog.vl_types.all;
entity sha256_w_mem is
    port(
        clk             : in     vl_logic;
        reset_n         : in     vl_logic;
        \block\         : in     vl_logic_vector(511 downto 0);
        round           : in     vl_logic_vector(5 downto 0);
        init            : in     vl_logic;
        \next\          : in     vl_logic;
        w               : out    vl_logic_vector(31 downto 0)
    );
end sha256_w_mem;
