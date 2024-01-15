// Copyright (c) 2023 Beijing Institute of Open Source Chip
// sram is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

`include "axi_define.sv"

module addr_ctrl (
    input  logic                        aclk_i,
    input  logic                        aresetn_i,
    input  logic [`AXI4_ADDR_WIDTH-1:0] addr_i,
    input  logic [                 2:0] asize_i,
    input  logic [                 1:0] aburst_i,
    input  logic [                 7:0] alen_i,
    input  logic                        avalid_i,
    output logic                        aready_o,
    output logic [`AXI4_ADDR_WIDTH-1:0] addr_o,
    output logic                        addr_last_o,
    output logic                        addr_valid_o,
    input  logic                        addr_ready_i
);

  logic [`AXI4_ADDR_OFT_WIDTH-1:0] s_oft_addr;
  logic [2:0] s_asize_d, s_asize_q;
  logic [1:0] s_aburst_d, s_aburst_q;
  logic [7:0] s_alen_d, s_alen_q;
  logic [7:0] s_cnt_d, s_cnt_q;
  logic s_cnt_en;
  logic [`AXI4_ADDR_WIDTH-1:0] s_addrout_d, s_addrout_q;
  logic s_addrout_en;
  logic s_addrlast_d, s_addrlast_q;
  logic s_addrvalid_d, s_addrvalid_q, s_addrvalid_en;
  logic s_axi_hdshk, s_addr_hdshk;

  assign aready_o     = ~s_addrvalid_q;
  assign addr_o       = s_addrout_q;
  assign addr_last_o  = s_addrlast_q;
  assign addr_valid_o = s_addrvalid_q;
  assign s_axi_hdshk  = avalid_i & aready_o;
  assign s_addr_hdshk = addr_valid_o && addr_ready_i;

  assign s_asize_d    = s_axi_hdshk ? asize_i : s_asize_q;
  dffer #(3) u_asize_dffer (
      aclk_i,
      aresetn_i,
      s_axi_hdshk,
      s_asize_d,
      s_asize_q
  );

  assign s_aburst_d = s_axi_hdshk ? aburst_i : s_aburst_q;
  dffer #(2) u_aburst_dffer (
      aclk_i,
      aresetn_i,
      s_axi_hdshk,
      s_aburst_d,
      s_aburst_q
  );

  assign s_alen_d = s_axi_hdshk ? alen_i : s_alen_q;
  dffer #(4) u_alen_dffer (
      aclk_i,
      aresetn_i,
      s_axi_hdshk,
      s_alen_d,
      s_alen_q
  );

  assign s_addrout_en = s_axi_hdshk || s_addr_hdshk;
  always_comb begin
    s_addrout_d = s_addrout_q;
    if (s_axi_hdshk) begin
      s_addrout_d = addr_i;
    end else if (s_addr_hdshk) begin
      s_addrout_d = {s_addrout_q[`AXI4_ADDR_WIDTH-1:`AXI4_ADDR_OFT_WIDTH], s_oft_addr};
    end
  end
  dffer #(`AXI4_ADDR_WIDTH) u_addrout_dffer (
      aclk_i,
      aresetn_i,
      s_addrout_en,
      s_addrout_d,
      s_addrout_q
  );


  assign s_cnt_en = s_axi_hdshk || s_addr_hdshk;
  always_comb begin
    s_cnt_d = s_cnt_q;
    if (s_axi_hdshk) begin
      s_cnt_d = alen_i;
    end else if (s_addr_hdshk) begin
      s_cnt_d = s_cnt_q - 1'b1;
    end
  end
  dffer #(8) u_cnt_dffer (
      aclk_i,
      aresetn_i,
      s_cnt_en,
      s_cnt_d,
      s_cnt_q
  );

  assign s_addrlast_d = s_cnt_d == '0;
  dffr #(1) u_addrlast_dffr (
      aclk_i,
      aresetn_i,
      s_addrlast_d,
      s_addrlast_q
  );


  assign s_addrvalid_en = s_axi_hdshk || (addr_ready_i && addr_last_o);
  always_comb begin
    s_addrvalid_d = s_addrvalid_q;
    if (s_axi_hdshk) begin
      s_addrvalid_d = 1'b1;
    end else if (addr_ready_i && addr_last_o) begin
      s_addrvalid_d = 1'b0;
    end
  end
  dffer #(1) u_addrvalid_dffer (
      aclk_i,
      aresetn_i,
      s_addrvalid_en,
      s_addrvalid_d,
      s_addrvalid_q
  );

  addr_gen u_addr_gen (
      .alen_i  (s_alen_q),
      .asize_i (s_asize_q),
      .aburst_i(s_aburst_q),
      .addr_i  (s_addrout_q[`AXI4_ADDR_OFT_WIDTH-1:0]),
      .addr_o  (s_oft_addr)
  );
endmodule
