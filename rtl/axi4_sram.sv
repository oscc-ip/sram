// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// -- Adaptable modifications are redistributed under compatible License --
//
// Copyright (c) 2023 Beijing Institute of Open Source Chip
// sram is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

`include "regfile.sv"
`include "axi4_define.sv"

// each sram block capacity is 4KB
module axi4_sram #(
    parameter int          SRAM_WORD_DEPTH = 512,
    parameter int          SRAM_BLOCK_SIZE = 4,
    parameter int unsigned SRAM_BASE_ADDR  = 32'h0F00_0000
) (
    axi4_if.slave axi4
);
  // simplify the sram control signal logic
  localparam int SRAM_BIT_WIDTH = `AXI4_DATA_WIDTH;

  sram_if sram;
  mem_ctrl u_mem_ctrl (
      axi4,
      sram
  );

  // decode and mux
  logic [       `AXI4_ADDR_WIDTH-1:0]                              s_axi_addr;
  logic [$clog2(SRAM_BLOCK_SIZE)-1:0]                              s_tech_sram_idx;
  logic [        SRAM_BLOCK_SIZE-1:0]                              s_tech_sram_en;
  logic [        SRAM_BLOCK_SIZE-1:0]                              s_tech_sram_wen;
  logic [        SRAM_BLOCK_SIZE-1:0][       SRAM_BIT_WIDTH/8-1:0] s_tech_sram_bm;
  logic [        SRAM_BLOCK_SIZE-1:0][$clog2(SRAM_WORD_DEPTH)-1:0] s_tech_sram_addr;
  logic [        SRAM_BLOCK_SIZE-1:0][         SRAM_BIT_WIDTH-1:0] s_tech_sram_dat_i;
  logic [        SRAM_BLOCK_SIZE-1:0][         SRAM_BIT_WIDTH-1:0] s_tech_sram_dat_o;

  always_comb begin
    s_axi_addr = '0;
    if (axi4.arvalid && axi4.arready) begin
      s_axi_addr = axi4.araddr - SRAM_BASE_ADDR;
    end else if (axi4.awvalid && axi4.awready) begin
      s_axi_addr = axi4.awaddr - SRAM_BASE_ADDR;
    end
  end

  // split the addr into 4KB
  assign s_tech_sram_idx = s_axi_addr[$clog2(
      SRAM_WORD_DEPTH*SRAM_BIT_WIDTH
  )+$clog2(
      SRAM_BLOCK_SIZE
  ):$clog2(
      SRAM_WORD_DEPTH*SRAM_BIT_WIDTH
  )];

  always_comb begin
    s_tech_sram_en[s_tech_sram_idx]    = sram.en_i;
    s_tech_sram_wen[s_tech_sram_idx]   = sram.wen_i;
    s_tech_sram_bm[s_tech_sram_idx]    = sram.bm_i;
    s_tech_sram_addr[s_tech_sram_idx]  = sram.addr_i;
    s_tech_sram_dat_i[s_tech_sram_idx] = sram.dat_i;
    sram.dat_o                         = s_tech_sram_dat_o[s_tech_sram_idx];
  end

  for (genvar i = 0; i < SRAM_BLOCK_SIZE; i++) begin
    // 4KB fast regfile sram
    tech_regfile_bm #(
        .BIT_WIDTH (SRAM_BIT_WIDTH),
        .WORD_DEPTH(SRAM_WORD_DEPTH)
    ) u_tech_regile_bm (
        .clk_i (sram.clk_i),
        .en_i  (s_tech_sram_en[i]),
        .wen_i (s_tech_sram_wen[i]),
        .bm_i  (s_tech_sram_bm[i]),
        .addr_i(s_tech_sram_addr[i]),
        .dat_i (s_tech_sram_dat_i[i]),
        .dat_o (s_tech_sram_dat_o[i])
    );
  end

endmodule
