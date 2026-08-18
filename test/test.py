# # SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# # SPDX-License-Identifier: Apache-2.0

# import cocotb
# from cocotb.clock import Clock
# from cocotb.triggers import ClockCycles


# @cocotb.test()
# async def test_project(dut):
#     dut._log.info("Start")

#     # Set the clock period to 10 us (100 KHz)
#     clock = Clock(dut.clk, 10, unit="us")
#     cocotb.start_soon(clock.start())

#     # Reset
#     dut._log.info("Reset")
#     dut.ena.value = 1
#     dut.ui_in.value = 0
#     dut.uio_in.value = 0
#     dut.rst_n.value = 0
#     await ClockCycles(dut.clk, 10)
#     dut.rst_n.value = 1

#     dut._log.info("Test project behavior")

#     # Set the input values you want to test
#     dut.ui_in.value = 20
#     dut.uio_in.value = 30

#     # Wait for one clock cycle to see the output values
#     await ClockCycles(dut.clk, 1)

#     # The following assersion is just an example of how to check the output values.
#     # Change it to match the actual expected output of your module:
#     assert dut.uo_out.value == 50

#     # Keep testing the module by changing the input values, waiting for
#     # one or more clock cycles, and asserting the expected output values.


# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge

# Must match the F_CLK/R_BAUD parameters word_to_uart is instantiated with
# in project.sv.
F_CLK = 50_000_000
R_BAUD = 115_200
BIT_CYCLES = F_CLK // R_BAUD  # clk cycles per UART bit period

WORD = 0x1A2B3C4D  # the constant driven into word_to_uart by project.sv


def tx_line(dut):
    """uo_out[0] carries message_out."""
    return int(dut.uo_out.value) & 1


def ready(dut):
    """uo_out[1] carries ready_uart."""
    return (int(dut.uo_out.value) >> 1) & 1


async def read_uart_frame(dut, timeout_bits=40):
    """Sample the tx line like a real UART receiver would: wait for the start
    bit's falling edge, then sample the middle of each following bit slot."""
    for _ in range(timeout_bits * BIT_CYCLES):
        if tx_line(dut) == 0:
            break
        await RisingEdge(dut.clk)
    else:
        raise TimeoutError(
            f"no start bit within {timeout_bits} bit periods "
            f"(ready_o={ready(dut)})"
        )

    await ClockCycles(dut.clk, BIT_CYCLES // 2)  # land mid start-bit
    assert tx_line(dut) == 0, "start bit should be low"

    bits = []
    for _ in range(9):  # 8 data bits (LSB first) + parity bit
        await ClockCycles(dut.clk, BIT_CYCLES)
        bits.append(tx_line(dut))

    await ClockCycles(dut.clk, BIT_CYCLES)
    stop_bit = tx_line(dut)
    assert stop_bit == 1, "stop bit should be high"

    data_bits, parity_bit = bits[:8], bits[8]
    data = sum(b << i for i, b in enumerate(data_bits))  # LSB first
    assert parity_bit == (bin(data).count("1") & 1), "parity mismatch"
    return data


@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Set the clock period to 20 ns (50 MHz), matching F_CLK
    clock = Clock(dut.clk, 20, unit="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    dut._log.info("Test project behavior")

    # Wait until the design reports it can accept a word
    while ready(dut) == 0:
        await RisingEdge(dut.clk)
    dut._log.info("DUT ready to accept word")

    # Pulse valid (ui_in[0]) for one clock cycle
    dut.ui_in.value = 1
    await ClockCycles(dut.clk, 1)
    dut.ui_in.value = 0

    # Receive the four bytes of the word, LSB byte first
    received = []
    for _ in range(4):
        byte = await read_uart_frame(dut)
        dut._log.info(f"Received byte: 0x{byte:02X} ({byte:#010b})")
        received.append(byte)

    dut._log.info("Received bytes: " + " ".join(f"0x{b:02X}" for b in received))

    expected = [(WORD >> (8 * i)) & 0xFF for i in range(4)]
    assert received == expected, (
        f"expected {[f'0x{b:02X}' for b in expected]}, "
        f"got {[f'0x{b:02X}' for b in received]}"
    )
    await ClockCycles(dut.clk,10)
