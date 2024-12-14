// Copyright (c) 2023-2024 Miao Yuchi <miaoyuchi@ict.ac.cn>
// sram is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

`include "axi4_if.sv"

module axi4_sram_bpl_tb ();
  localparam CLK_PEROID = 10;
  logic rst_n_i, clk_i;

  initial begin
    clk_i = 1'b0;
    forever begin
      #(CLK_PEROID / 2) clk_i <= ~clk_i;
    end
  end

  task sim_reset(int delay);
    rst_n_i = 1'b0;
    repeat (delay) @(posedge clk_i);
    #1 rst_n_i = 1'b1;
  endtask

  initial begin
    sim_reset(40);
  end

  axi4_if u_axi4_if (
      clk_i,
      rst_n_i
  );


  test_top u_test_top (u_axi4_if.master);
  axi4_sram_bpl #(
      .SRAM_WORD_DEPTH(512),
      .SRAM_BLOCK_SIZE(4)
  ) u_axi4_sram_bpl (
      u_axi4_if.slave
  );

endmodule
