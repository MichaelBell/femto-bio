.include "macros.s"

.section .text,"ax"

_start: 
    li a4, 3    # TX on pin 3, could be fed from FIFO or elsewhere
                # Note this program will only work for pin <= 24

    # Setup IO mask
    li a5, 1
    sll a5, a5, a4
    wriomsk a5
    setoe   a5
    
tx_loop:    
    setio a5    # Idle high
    rdf0 a0

    # Have data to TX, wait for quantum so first period is full length
    waitq

    # Start bit
    clrio x0

    # Shift data into place
    sll a0, a0, a4

    # Transmit 8 bits
    li a3, 8

1:  # Bit loop
    waitq
    wrio a0
    srli a0, a0, 1
    addi a3, a3, -1
    bnez a3, 1b

    # Stop bit
    waitq
    setio a5
    waitq

    j tx_loop
