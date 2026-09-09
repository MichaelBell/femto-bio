.include "macros.s"

.section .text,"ax"

_start: 
   li  a0, 0x2000      # bit mask for pin 13
   li  a1, 8           # Loop count
   wriomsk a0          # GPIO mask = output pin
   setoe   a0          # pin = output
1:
   setio   a0          # set pin HIGH
   mv  a2, a1
2:
   addi a2, a2, -1
   bnez a2, 2b

   clrio   x0          # clear pin LOW
   mv  a2, a1
3:
   addi a2, a2, -1
   bnez a2, 3b

   j   1b              # loop
