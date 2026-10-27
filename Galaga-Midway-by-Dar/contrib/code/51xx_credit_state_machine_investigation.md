# Namco 51XX coin/credit state machine — investigation

Documents the relationship between the
`cs51XX` coin/credit state machine signals
(`cs51XX_switch_mode`, `cs51XX_credit_mode`, `credit_bcd`, `cs51XX_coin_mode_cnt`) and the
one-line coin-edge fix `galaga_credit_mode_fix.patch` (`cs51XX_credit_mode <= '1'`).

## Where the logic lives

`rtl_dar/galaga.vhd` (pristine tree), the `cs51XX` emulation. Reference line numbers are for
the patched file.

- `cs51XX_credit_mode` gates **only** the hardware credit-decrement / start-consume logic
  (lines 860-889). It is *not* what selects the CPU's switch vs. credit *data reads*.
- `cs51XX_switch_mode` selects the 51XX data read path
  (`cs51XX_do <= cs51XX_switch_mode_do when cs51XX_switch_mode='1' else cs51XX_non_switch_mode_do`,
  line 906). Switch reads carry left/right/fire and `b_test/b_svce/coin/start1/start2/fire_mem`
  (895-898); non-switch reads carry `credit_bcd_1 & credit_bcd_0` (901).
- `credit_bcd` (two BCD digits, `credit_bcd_0`/`credit_bcd_1`) is owned by the hardware:
  incremented on a coin edge (847-857), decremented on a start edge while in credit mode.

Mode is toggled by CPU writes to device #1 (`io_we` block, 759-786):
- data `"010"` → `switch_mode='0'`, `credit_mode='1'` (credit mode)
- data `"101"` → `switch_mode='1'`, `credit_mode='0'` (switch mode)
- data `"001"` → enter coin mode (`cs51XX_coin_mode_cnt <= "100"`); the next 4 writes to
  device #1 count it down and are ignored (coin-mode handshake, 780-784)

`cs51XX_credit_mode` is set to `'1'` by: reset (710), a CPU `"010"` write (770), and the fix's
coin edge (848). It is cleared to `'0'` by: a CPU `"101"` write (776), and a start1/start2 edge
in credit mode (862/876/885).

## The patch

`galaga_credit_mode_fix.patch` adds exactly one line to the coin-edge block (line 848):

```vhdl
if coin = '1' and coin_r = '0' then
    cs51XX_credit_mode <= '1';   -- <-- the fix
    ...
end if;
```

## Root cause of the reported bug (Start 1 / Start 2 ignored after a coin)

During attract/polling the CPU runs in **switch mode** (`credit_mode='0'`, reading coin/start
switches). Inserting a coin increments `credit_bcd` in hardware but leaves `credit_mode='0'`.
A subsequent start press falls through the `if cs51XX_credit_mode = '1'` gate (860), so the
credit is never decremented and the start is dropped. The fix re-enables the start-consumption
path at the moment a coin arrives, so the first start after a coin is honored regardless of the
CPU's current mode.

## Assessment

- **Correct and sufficient** for the intended behavior. No double-counting: CPU writes to
  credits are ignored during coin mode (782); the hardware owns `credit_bcd`.
- **Minor side effects (acceptable):**
  1. It transiently leaves `switch_mode='1'` **and** `credit_mode='1'` (normally
     complementary). Harmless — switch reads depend only on `switch_mode`; the effect is simply
     that starts become immediately consumable.
  2. A coin and a start on the *same* clock edge: both blocks are in one process with
     last-write-wins semantics, so the start decrement overwrites the coin increment (0 net
     credit change + a consumed start), vs. pre-patch which only incremented. Negligible
     physically (requires exact-cycle coincidence).
- **Not a full re-enable model:** after a start clears `credit_mode`, it stays off until the
  next coin (the fix) or a CPU `"010"` write. Re-play with credits remaining (no new coin) relies
  on the CPU writing `"010"` when it returns to the title, which is the normal game flow.

## Conclusion

The fix is a sound, targeted hardware-model correction; the mechanism is understood and the side
effects are negligible. The remaining validation is on-hardware (start/coin behavior), already
tracked in `PORTING_SPEC.md` §11.

