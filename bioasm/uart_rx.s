.include "macros.s"

.section .text,"ax"

# UART RX, requires quantum running 5x faster than the baud rate
_start: 
    li a4, 2    # RX on pin 2, could be fed from FIFO or elsewhere

    # Setup IO mask
    li a5, 1
    sll a5, a5, a4

    # Setup receive bit shift, will shift bit from pin to top of word
    li a3, 31
    sub a4, a3, a4

rx_start_detect:
    # Look for RX pin low
    rdio a0
    and a0, a0, a5
    beq a0, a5, rx_start_detect

    # 3 quanta gets us into the middle of the bit,
    # because the first edge wasn't aligned to a quantum the first
    # waitq will in general be less than a full period.
    waitq
    waitq
    waitq

    # Ignore glitches
    rdio a0
    and a0, a0, a5
    beq a0, a5, rx_start_detect

    li a3, 8
rx_loop:
    # Wait 5 quanta to the middle of the next bit
    waitq
    addi a3, a3, -1  # Housekeeping while waiting
    srli a1, a1, 1   # Shift result data down (receive LSB first)
    waitq
    waitq
    waitq
    waitq
    rdio a0
    and a0, a0, a5
    sll a0, a0, a4   # Shift new data to top bit
    or a1, a1, a0    # and OR into result
    bnez a3, rx_loop

    waitq
    srli a1, a1, 24  # Align received data to bottom
    waitq
    waitq
    waitq
    waitq

    # Check stop bit, ignore data if it is low
    rdio a0
    and a0, a0, a5
    beqz a0, rx_start_detect

    # Write byte to FIFO
    wrf1 a1

    j rx_start_detect
