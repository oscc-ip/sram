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
  bit [`AXI4_DATA_WIDTH-1:0] trans_wdata[$];
  bit [`AXI4_ADDR_WIDTH-1:0] trans_addr;
  bit [                 2:0] trans_size;
  int                        trans_len;
  int                        trans_id;

  for (int i = 0; i < 3000; i++) begin
    trans_len   = {$random} % 60 + 2;
    trans_id    = {$random} % 16;
    trans_addr  = 32'h0F00_0000 + {({$random} % 32'h0F30) >> 3, 3'b000};  // slice sram 1
    trans_size  = {$random} % 4;
    // $display("trans_addr: %h", trans_addr);
    trans_wdata = {};
    for (int j = 0; j < trans_len; j++) begin
      trans_wdata.push_back({$random, $random});
      // if (j >= trans_len - 4) begin
      //   $display("trans_wdata: %h", trans_wdata[j]);
      // end
      // trans_wdata.push_back(j);
    end

    this.write(.id(trans_id), .addr(trans_addr), .len(trans_len), .size(trans_size),
               .burst(`AXI4_BURST_TYPE_INCR), .data(trans_wdata));
    repeat (100) @(posedge this.axi4.aclk);

    this.rd_check(.id(trans_id), .addr(trans_addr), .len(trans_len), .size(trans_size),
                  .burst(`AXI4_BURST_TYPE_INCR), .ref_data(trans_wdata), .cmp_type(Helper::EQUL));

  end
  $display("align wr/rd test done");
endtask

`endif
