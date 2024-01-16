// Copyright (c) 2023 Beijing Institute of Open Source Chip
// sram is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

`ifndef INC_SRAM_TEST_SV
`define INC_SRAM_TEST_SV

`include "axi4_master.sv"
`include "axi4_define.sv"

class SRAMTest extends AXI4Master;
  string                 name;
  int                    wr_val;
  virtual axi4_if.master axi4;

  extern function new(string name = "sram_test", virtual axi4_if.master axi4);
  extern task automatic align_wr_rd_test();
endclass

function SRAMTest::new(string name, virtual axi4_if.master axi4);
  super.new("axi4_master", axi4);
  this.name   = name;
  this.wr_val = 0;
  this.axi4   = axi4;
endfunction

task automatic SRAMTest::align_wr_rd_test();
  bit [`AXI4_DATA_WIDTH-1:0] val[$] = {64'h1234_5678};

  this.write(.id('1), .addr(32'h0F00_0000), .len(0), .size(`AXI4_BURST_SIZE_8BYTES),
             .burst(`AXI4_BURST_TYPE_FIXED), .data(val), .strb(8'b1111_1111));

  this.read(.id('1), .addr(32'h0F00_0000), .len(0), .size(`AXI4_BURST_SIZE_8BYTES),
            .burst(`AXI4_BURST_TYPE_FIXED));

  foreach (super.rd_data[i]) begin
    $display("%t rd_data[%d]: %h", $time, i, super.rd_data[i]);
  end
endtask

`endif
