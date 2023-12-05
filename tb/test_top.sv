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
`include "helper.sv"
`include "pwm_define.sv"

program automatic test_top (
    apb4_if.master apb4,
    pwm_if.tb   pwm
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

  PWMTest pwm_hdl;

  initial begin
    Helper::start_banner();
    sim_config();
    @(posedge apb4.presetn);
    Helper::print("tb init done");
    pwm_hdl = new("pwm_test", apb4, pwm);
    pwm_hdl.init();
    pwm_hdl.test_reset_reg();
    pwm_hdl.test_wr_rd_reg();
    pwm_hdl.test_clk_div();
    pwm_hdl.test_inc_cnt();
    pwm_hdl.test_pwm();
    pwm_hdl.test_irq();

    Helper::end_banner();
    #20000 $finish;
  end

endprogram
