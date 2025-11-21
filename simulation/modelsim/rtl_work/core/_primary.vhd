library verilog;
use verilog.vl_types.all;
entity core is
    port(
        clk             : in     vl_logic;
        reset_n         : in     vl_logic;
        init            : in     vl_logic;
        \next\          : in     vl_logic;
        \block\         : in     vl_logic_vector(511 downto 0);
        ready           : out    vl_logic;
        digest          : out    vl_logic_vector(255 downto 0);
        digest_valid    : out    vl_logic
    );
end core;
