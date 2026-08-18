# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge

# Must match the F_CLK/R_BAUD parameters uart_tx is instantiated with
# (tb_uart_tx.v uses the module defaults).
F_CLK = 50_000_000
R_BAUD = 115_200
BIT_CYCLES = F_CLK // R_BAUD  # clk cycles per UART bit period


async def send_byte(dut, byte):
    """valid/ready handshake: wait for ready_o, present data_i, then pulse
    valid_i for one clk cycle."""
    while dut.ready_o.value != 1:
        await RisingEdge(dut.clk)
    dut.data_i.value = byte
    dut.valid_i.value = 1
    await RisingEdge(dut.clk)
    dut.valid_i.value = 0


async def read_uart_frame(dut):
    """Sample message_o like a real UART receiver would: detect the start
    bit's falling edge, then sample the middle of each following bit slot."""
    while dut.message_o.value == 1:
        await RisingEdge(dut.clk)

    await ClockCycles(dut.clk, BIT_CYCLES // 2)  # land mid start-bit
    start_bit = int(dut.message_o.value)

    bits = []
    for _ in range(9):  # 8 data bits + parity bit
        await ClockCycles(dut.clk, BIT_CYCLES)
        bits.append(int(dut.message_o.value))

    await ClockCycles(dut.clk, BIT_CYCLES)
    stop_bit = int(dut.message_o.value)

    data_bits, parity_bit = bits[:8], bits[8]
    return start_bit, data_bits, parity_bit, stop_bit


@cocotb.test()
async def test_uart_tx_frame(dut):
    dut._log.info("Start")

    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())

    dut._log.info("Reset")
    dut.data_i.value = 0
    dut.valid_i.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)

    assert dut.ready_o.value == 1, "ready_o should be high after reset"

    test_byte = 0b1010_0101  # 0xA5 - mixed bits, easy to eyeball in waves

    dut._log.info(f"Sending byte {test_byte:#04x}")
    cocotb.start_soon(send_byte(dut, test_byte))

    start_bit, data_bits, parity_bit, stop_bit = await read_uart_frame(dut)

    assert start_bit == 0, f"Start bit should be 0, got {start_bit}"
    assert stop_bit == 1, f"Stop bit should be 1, got {stop_bit}"

    received_byte = 0
    for i, b in enumerate(data_bits):  # LSB first
        received_byte |= (b << i)

    assert received_byte == test_byte, (
        f"Expected {test_byte:#010b}, received {received_byte:#010b}"
    )

    expected_parity = 0
    for i in range(8):
        expected_parity ^= (test_byte >> i) & 1
    assert parity_bit == expected_parity, (
        f"Expected parity {expected_parity}, got {parity_bit}"
    )

    # ready_o should return high once the frame finishes
    await ClockCycles(dut.clk, 5)
    assert dut.ready_o.value == 1, "ready_o should be high again after transmission"

    dut._log.info("UART frame received and decoded correctly")

