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
  extern task automatic seq_wr_rd_test();
  extern task automatic align_wr_rd_test();
endclass

function SRAMTest::new(string name, virtual axi4_if.master axi4);
  super.new("axi4_master", axi4);
  this.name   = name;
  this.wr_val = 0;
  this.axi4   = axi4;
endfunction

// 4KB block addr: 'h0000~'h0FFF
//                 'h1000~'h1FFF
//                 'h2000~'h2FFF
//                 'h3000~'h3FFF
task automatic SRAMTest::seq_wr_rd_test();
  bit [`AXI4_DATA_WIDTH-1:0] trans_wdata[$];
  bit [`AXI4_ADDR_WIDTH-1:0] trans_addr;
  bit [                15:0] trans_num;
  bit [                 7:0] delta_addr;

  $display("seq wr/rd test");
  for (int i = 0; i < 4; i++) begin
    // i = 0: delta_addr = 1 trans_num = 8000 size = 0
    // i = 1: delta_addr = 2 trans_num = 4000 size = 1
    // i = 2: delta_addr = 4 trans_num = 2000 size = 2
    // i = 3: delta_addr = 8 trans_num = 1000 size = 3
    delta_addr = 1 << i;
    trans_num  = 1000 * (1 << (3 - i));
    trans_addr = 32'h0F00_0000;
    $display("delta_addr: %d trans_num: %d", delta_addr, trans_num);
    for (int j = 0; j < trans_num; j++) begin
      trans_wdata = {};
      trans_wdata.push_back(j);
      this.axi4_write(.id('0), .addr(trans_addr), .len(1), .size(i), .burst(`AXI4_BURST_TYPE_INCR),
                      .data(trans_wdata));
      repeat (100) @(posedge this.axi4.aclk);
      trans_addr += delta_addr;
    end

    trans_addr = 32'h0F00_0000;
    for (int j = 0; j < trans_num; j++) begin
      trans_wdata = {};
      trans_wdata.push_back(j);
      this.axi4_rd_check(.id('0), .addr(trans_addr), .len(1), .size(i),
                         .burst(`AXI4_BURST_TYPE_INCR), .ref_data(trans_wdata),
                         .cmp_type(Helper::EQUL));
      trans_addr += delta_addr;
    end

  end

endtask

task automatic SRAMTest::align_wr_rd_test();
  bit [`AXI4_DATA_WIDTH-1:0] trans_wdata [$];
  bit [`AXI4_ADDR_WIDTH-1:0] trans_addr;
  bit [`AXI4_ADDR_WIDTH-1:0] trans_baddr;
  bit [                 2:0] trans_size;
  bit [                 1:0] trans_type;
  int                        trans_len;
  int                        trans_id;

  $display("align random burst wr/rd test");
  for (int i = 0; i < 3000; i++) begin
    trans_len   = {$random} % 60 + 2;
    trans_id    = {$random} % 16;
    trans_size  = {$random} % 4;
    trans_type  = {$random} % 2;
    trans_baddr = 32'h0F00_0000 + ({$random} % 3) * 32'h1000;
    // generate aligned addr
    trans_addr  = trans_baddr + ((({$random} % 32'h0F30) >> trans_size) << trans_size);
    // $display("trans_size: %h trans_addr: %h", trans_size, trans_addr);
    trans_wdata = {};
    for (int j = 0; j < trans_len; j++) begin
      trans_wdata.push_back({$random, $random});
      // if (j >= trans_len - 4) begin
      //   $display("trans_wdata: %h", trans_wdata[j]);
      // end
      // trans_wdata.push_back(j);
    end

    if (trans_type == `AXI4_BURST_TYPE_FIXED) begin
      trans_len = 1;
    end
    this.axi4_write(.id(trans_id), .addr(trans_addr), .len(trans_len), .size(trans_size),
                    .burst(trans_type), .data(trans_wdata));
    repeat (100) @(posedge this.axi4.aclk);

    this.axi4_rd_check(.id(trans_id), .addr(trans_addr), .len(trans_len), .size(trans_size),
                       .burst(trans_type), .ref_data(trans_wdata), .cmp_type(Helper::EQUL));
  end
  // $display("align random burst wr/rd test done");
endtask


`endif
