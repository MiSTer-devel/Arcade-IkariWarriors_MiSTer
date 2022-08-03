create_generated_clock -name clk_107p2 -source \
    [get_pins {emu|pll|pll_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk}] \
    -divide_by 1

create_generated_clock -name clk_107p2s -source \
    [get_pins {emu|pll|pll_inst|altera_pll_i|general[2].gpll~PLL_OUTPUT_COUNTER|divclk}] \
    -divide_by 1

derive_pll_clocks
derive_clock_uncertainty

# core specific constraints
set_multicycle_path -setup -end \
  -rise_from [get_clocks {clk_107p2s}] \
  -rise_to [get_clocks {clk_107p2}] 2
