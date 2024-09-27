// Copyright (c) 2023 Beijing Institute of Open Source Chip
// sram is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

`include "axi4_if.sv"
`include "helper.sv"

program automatic test_top (
    axi4_if.master axi4
);

  string wave_name = "default.fsdb";
  task sim_config();
    $timeformat(-9, 1, "ns", 10);
    if ($test$plusargs("WAVE_ON")) begin
      $value$plusargs("WAVE_NAME=%s", wave_name);
      $fsdbDumpfile(wave_name);
      $fsdbDumpvars("+all");
    end
  endtask

  SRAMTest sram_hdl;

  initial begin
    Helper::start_banner();
    sim_config();
    @(posedge axi4.aresetn);
    Helper::print("tb init done");
    sram_hdl = new("sram_test", axi4);
    sram_hdl.init();
    sram_hdl.seq_wr_rd_test();
    sram_hdl.align_wr_rd_test();
    Helper::end_banner();
    #20000 $finish;
  end

endprogram
