// Copyright (c) 2023 Beijing Institute of Open Source Chip
// sram is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

module addr_gen (
    input  logic [11:0] addr_i,     // no cross 4KB
    input  logic [ 3:0] axlen_i,
    input  logic [ 2:0] axsize_i,
    input  logic [ 1:0] axburst_i,
    output logic [11:0] addr_o
);

  logic [11:0] s_offset_addr, s_inc_addr, s_wrap_addr;
  logic [11:0] s_mux_addr, s_res_addr;

  always_comb begin
    s_offset_addr = '0;
    unique case (axsize_i)
      `AXI4_BURST_SIZE_1BYTE:     s_offset_addr = addr_i[11:0];
      `AXI4_BURST_SIZE_2BYTES:    s_offset_addr = {1'b0, addr_i[11:1]};
      `AXI4_BURST_SIZE_4BYTES:    s_offset_addr = {2'b00, addr_i[11:2]};
      `AXI4_BURST_SIZE_8BYTES:    s_offset_addr = {3'b000, addr_i[11:3]};
      default s_offset_addr = '0;
    endcase
  end

  assign s_inc_addr        = s_offset_addr + 1'b1;
  assign s_wrap_addr[11:4] = s_offset_addr[11:4];
  assign s_wrap_addr[3:0]  = (axlen_i & s_inc_addr[3:0]) | (~axlen_i & s_offset_addr[3:0]);
  assign s_mux_addr        = axburst_i == `AXI4_BURST_TYPE_WRAP ? s_wrap_addr : s_inc_addr;

  always_comb begin
    s_res_addr = '0;
    unique case (axsize_i)
      `AXI4_BURST_SIZE_1BYTE:  s_res_addr = s_mux_addr;
      `AXI4_BURST_SIZE_2BYTES: s_res_addr = {s_mux_addr[10:0], 1'b0};
      `AXI4_BURST_SIZE_4BYTES: s_res_addr = {s_mux_addr[9:0], 2'b00};
      `AXI4_BURST_SIZE_8BYTES: s_res_addr = {s_mux_addr[8:0], 3'b000};
      default s_res_addr = '0;
    endcase
  end

  assign addr_o = axburst_i == `AXI4_BURST_TYPE_FIXED ? addr_i : s_res_addr;
endmodule
