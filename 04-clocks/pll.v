// ===========================================================================
//  GENERATED FILE — do not edit the parameters by hand.
//
//  Produced by prjtrellis's PLL calculator:
//
//    ecppll -n pll -i 25 -o 100 --clkout1 40 \
//           --clkin_name clk_25mhz --clkout0_name clk_100mhz \
//           --clkout1_name clk_40mhz -f pll.v
//
//  which reported:
//    refclk divisor 1, feedback divisor 4, VCO 600 MHz
//    clkout0 divisor 6  -> 100 MHz
//    clkout1 divisor 15 ->  40 MHz
//
//  EHXPLLL is a HARD BLOCK: a real analogue phase-locked loop in the corner of
//  the die, not logic. That has three consequences worth knowing:
//
//    1. The parameters are not arbitrary. The VCO must land in its legal range
//       (roughly 400-800 MHz), and every output is that one VCO frequency
//       divided by an integer. You cannot ask for any pair of frequencies you
//       like — hence the calculator.
//    2. It cannot be simulated by iverilog. EHXPLLL is a black box with no
//       behavioural model here, so this lesson's testbench does not
//       instantiate it; it generates two clocks directly instead. The PLL is
//       verified structurally (it synthesises, nextpnr reports the
//       frequencies) and on hardware (the `locked` output, and the LEDs).
//    3. `locked` goes high when the loop has settled, some tens of
//       microseconds after power-up. Logic in a PLL domain should be held in
//       reset until then — see clocks_top.v.
// ===========================================================================
module pll
(
    input clk_25mhz, // 25 MHz, 0 deg
    output clk_100mhz, // 100 MHz, 0 deg
    output clk_40mhz, // 40 MHz, 0 deg
    output locked
);
(* FREQUENCY_PIN_CLKI="25" *)
(* FREQUENCY_PIN_CLKOP="100" *)
(* FREQUENCY_PIN_CLKOS="40" *)
(* ICP_CURRENT="12" *) (* LPF_RESISTOR="8" *) (* MFG_ENABLE_FILTEROPAMP="1" *) (* MFG_GMCREF_SEL="2" *)
EHXPLLL #(
        .PLLRST_ENA("DISABLED"),
        .INTFB_WAKE("DISABLED"),
        .STDBY_ENABLE("DISABLED"),
        .DPHASE_SOURCE("DISABLED"),
        .OUTDIVIDER_MUXA("DIVA"),
        .OUTDIVIDER_MUXB("DIVB"),
        .OUTDIVIDER_MUXC("DIVC"),
        .OUTDIVIDER_MUXD("DIVD"),
        .CLKI_DIV(1),
        .CLKOP_ENABLE("ENABLED"),
        .CLKOP_DIV(6),
        .CLKOP_CPHASE(2),
        .CLKOP_FPHASE(0),
        .CLKOS_ENABLE("ENABLED"),
        .CLKOS_DIV(15),
        .CLKOS_CPHASE(2),
        .CLKOS_FPHASE(0),
        .FEEDBK_PATH("CLKOP"),
        .CLKFB_DIV(4)
    ) pll_i (
        .RST(1'b0),
        .STDBY(1'b0),
        .CLKI(clk_25mhz),
        .CLKOP(clk_100mhz),
        .CLKOS(clk_40mhz),
        .CLKOS2(),
        .CLKOS3(),
        .CLKFB(clk_100mhz),
        .CLKINTFB(),
        .PHASESEL0(1'b0),
        .PHASESEL1(1'b0),
        .PHASEDIR(1'b1),
        .PHASESTEP(1'b1),
        .PHASELOADREG(1'b1),
        .PLLWAKESYNC(1'b0),
        .ENCLKOP(1'b0),
        .LOCK(locked),
        .ENCLKOS(),
        .ENCLKOS2(),
        .ENCLKOS3(),
        .INTLOCK(),
        .REFCLK()
	);
endmodule
