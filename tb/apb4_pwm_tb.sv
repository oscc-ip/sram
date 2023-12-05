// Copyright (c) 2023 Beijing Institute of Open Source Chip
// pwm is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

`include "apb4_if.sv"
`include "pwm_define.sv"

module apb4_pwm_tb ();
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

  apb4_if u_apb4_if (
      clk_i,
      rst_n_i
  );

  pwm_if u_pwm_if ();

  test_top u_test_top (
      .apb4(u_apb4_if.master),
      .pwm (u_pwm_if.tb)
  );
  apb4_pwm u_apb4_pwm (
      .apb4(u_apb4_if.slave),
      .pwm (u_pwm_if.dut)
  );

endmodule
