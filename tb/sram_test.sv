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
  bit [`AXI4_DATA_WIDTH-1:0] wr_data[$] = {};
  int tmp_num;

  // fixed wr and rd
  for (int i = 0; i < 1000; i++) begin
    // $display("%t: %d", $time, i);
    wr_data = {};
    tmp_num = {$random} % 60 + 2;
    for(int j = 0; j < tmp_num; j++) begin
      wr_data.push_back({$random, $random});
    end

    this.write(.id('1), .addr(32'h0F00_0000), .len(tmp_num), .size(`AXI4_BURST_SIZE_8BYTES),
               .burst(`AXI4_BURST_TYPE_INCR), .data(wr_data), .strb(8'b1111_1111));
    repeat (100) @(posedge this.axi4.aclk);

    // $display("wr done");
    this.rd_check(.id('1), .addr(32'h0F00_0000), .len(tmp_num), .size(`AXI4_BURST_SIZE_8BYTES),
                  .burst(`AXI4_BURST_TYPE_INCR), .ref_data(wr_data), .cmp_type(Helper::EQUL));
    // this.read(.id('1), .addr(32'h0F00_0000), .len(3), .size(`AXI4_BURST_SIZE_8BYTES),
    //           .burst(`AXI4_BURST_TYPE_INCR));
    // repeat (100) @(posedge this.axi4.aclk);

    // foreach (super.rd_data[i]) begin
    //   if (super.rd_data[i] != wr_data[i]) begin
    //     $display("%t [%d]: wr_data: %hrd_data: %h", $time, i, wr_data[i], super.rd_data[i]);
    //   end
    // end

  end
  $display("align 8Btyes wr/rd test done");
endtask

`endif
