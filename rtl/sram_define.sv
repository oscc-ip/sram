// Copyright (c) 2023 Beijing Institute of Open Source Chip
// sram is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

`ifndef INC_SRAM_DEF_SV
`define INC_SRAM_DEF_SV

interface sram_if #(
    parameter int BIT_WIDTH  = 64,
    parameter int WORD_DEPTH = 512
) ();
  logic                          clk_i;
  logic                          en_i;
  logic                          wen_i;
  logic [       BIT_WIDTH/8-1:0] bm_i;
  logic [$clog2(WORD_DEPTH)-1:0] addr_i;
  logic [         BIT_WIDTH-1:0] dat_i;
  logic [         BIT_WIDTH-1:0] dat_o;

  modport dut(
      input clk_i,
      input en_i,
      input wen_i,
      input bm_i,
      input addr_i,
      input addr_i,
      output addr_o
  );
  modport tb(
      output clk_i,
      output en_i,
      output wen_i,
      output bm_i,
      output addr_i,
      output addr_i,
      input addr_o
  );
endinterface

`endif
