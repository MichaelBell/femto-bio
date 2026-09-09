# FIFO - 8-deep fifo head/tail access. Cores halt on overflow/underflow.
# - x16 r/w  fifo[0]
# - x17 r/w  fifo[1]
# - x18 r/w  fifo[2]
# - x19 r/w  fifo[3]

.macro rdf0 dst_reg
  mv \dst_reg, x16
.endm

.macro rdf1 dst_reg
  mv \dst_reg, x17
.endm

.macro rdf2 dst_reg
  mv \dst_reg, x18
.endm

.macro rdf3 dst_reg
  mv \dst_reg, x19
.endm

.macro wrf0 src_reg
  mv x16, \src_reg
.endm

.macro wrf1 src_reg
  mv x17, \src_reg
.endm

.macro wrf2 src_reg
  mv x18, \src_reg
.endm

.macro wrf3 src_reg
  mv x19, \src_reg
.endm

# Quantum - core will halt until host-configured clock divider pulse occurs,
# or an external event comes in on a host-specified GPIO pin.
# - x20 -/w  halt to quantum

.macro waitq
  li x20, 0
.endm

# GPIO - note clear-on-0 semantics for bit-clear for data pins!
#   This is done so we can do a shift-and-move without an invert to
#   bitbang a data pin. Direction retains a more "conventional" meaning
#   where a write of `1` to either clear or set will cause the action,
#   as pin direction toggling is less likely to be in a tight inner loop.
# - x21 r/w  write: (x26 & x21) -> gpio pins; read: gpio pins -> x21
# - x22 -/w  (x26 & x22) -> a `1` in x22 will set corresponding pin on gpio
# - x23 -/w  (x26 & ~x23) -> a `0` in x23 will clear corresponding pin on gpio
# - x24 -/w  (x26 & x24) -> a `1` in x24 will make corresponding gpio pin an output
# - x25 -/w  (x26 & x25) -> a `1` in x25 will make corresponding gpio pin an input
# - x26 r/w  mask GPIO action outputs

.macro wrio src_reg  # write IO (masked)
  mv x21, \src_reg
.endm

.macro rdio dst_reg  # read IO (masked)
  mv \dst_reg, x21
.endm

.macro setio src_reg  # 1 bits set output high (masked)
  mv x22, \src_reg
.endm

.macro clrio src_reg  # 0 bits set output low (masked)
  mv x23, \src_reg
.endm

.macro setoe src_reg  # 1 bits set output enable (masked)
  mv x24, \src_reg
.endm

.macro setod src_reg  # 1 bits clear output enable (masked) (mnemonic is set output disable)
  mv x25, \src_reg
.endm

.macro wriomsk src_reg
  mv x26, \src_reg
.endm

.macro rdiomsk dst_reg
  mv \dst_reg, x26
.endm

# Events - operate on a shared event register. Bits [31:24] are hard-wired to FIFO
# level flags, configured by the host; writes to bits [31:24] are ignored.
# - x27 -/w  mask event sensitivity bits
# - x28 -/w  `1` will set the corresponding event bit. Only [23:0] are wired up.
# - x29 -/w  `1` will clear the corresponding event bit Only [23:0] are wired up.
# - x30 r/-  halt until ((x27 & events) != 0), and return unmasked `events` value

.macro wrevmsk src_reg
  mv x27, \src_reg
.endm

.macro setev src_reg  # 1 bits set event bits
  mv x28, \src_reg
.endm

.macro clrev src_reg  # 1 bits clear event bits
  mv x29, \src_reg
.endm

.macro waitev dst_reg
  mv \dst_reg, x30
.endm

# Core ID & debug:
# - x31 r/-  [31:30] -> core ID; [29:0] -> cpu clocks since reset
