// Copyright (c) 2023 Beijing Institute of Open Source Chip
// sram is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

`include "axi_define.sv"

module addr_gen (
    input  logic [                     3:0] alen_i,
    input  logic [                     2:0] asize_i,
    input  logic [                     1:0] aburst_i,
    input  logic [`AXI4_ADDR_OFT_WIDTH-1:0] addr_i,
    output logic [`AXI4_ADDR_OFT_WIDTH-1:0] addr_o
);

  logic [`AXI4_ADDR_OFT_WIDTH-1:0] s_offset_addr, s_inc_addr, s_wrap_addr;
  logic [`AXI4_ADDR_OFT_WIDTH-1:0] s_mux_addr, s_res_addr;

  // max 64 bits
  always_comb begin
    s_offset_addr = '0;
    unique case (asize_i)
      `AXI4_BURST_SIZE_1BYTE:     s_offset_addr = addr_i[`AXI4_ADDR_OFT_WIDTH-1:0];
      `AXI4_BURST_SIZE_2BYTES:    s_offset_addr = {1'b0, addr_i[`AXI4_ADDR_OFT_WIDTH-1:1]};
      `AXI4_BURST_SIZE_4BYTES:    s_offset_addr = {2'b00, addr_i[`AXI4_ADDR_OFT_WIDTH-1:2]};
      `AXI4_BURST_SIZE_8BYTES:    s_offset_addr = {3'b000, addr_i[`AXI4_ADDR_OFT_WIDTH-1:3]};
      default s_offset_addr = '0;
    endcase
  end

  assign s_inc_addr = s_offset_addr + 1'b1;
  assign s_wrap_addr[`AXI4_ADDR_OFT_WIDTH-1:4] = s_offset_addr[`AXI4_ADDR_OFT_WIDTH-1:4];
  assign s_wrap_addr[3:0] = (alen_i & s_inc_addr[3:0]) | (~alen_i & s_offset_addr[3:0]);
  assign s_mux_addr = aburst_i == `AXI4_BURST_TYPE_WRAP ? s_wrap_addr : s_inc_addr;

  always_comb begin
    s_res_addr = '0;
    unique case (asize_i)
      `AXI4_BURST_SIZE_1BYTE:  s_res_addr = s_mux_addr;
      `AXI4_BURST_SIZE_2BYTES: s_res_addr = {s_mux_addr[`AXI4_ADDR_OFT_WIDTH-2:0], 1'b0};
      `AXI4_BURST_SIZE_4BYTES: s_res_addr = {s_mux_addr[`AXI4_ADDR_OFT_WIDTH-3:0], 2'b00};
      `AXI4_BURST_SIZE_8BYTES: s_res_addr = {s_mux_addr[`AXI4_ADDR_OFT_WIDTH-4:0], 3'b000};
      default s_res_addr = '0;
    endcase
  end

  assign addr_o = aburst_i == `AXI4_BURST_TYPE_FIXED ? addr_i : s_res_addr;
endmodule
