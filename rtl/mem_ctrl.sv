// Copyright (c) 2023 Beijing Institute of Open Source Chip
// sram is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

`include "register.sv"
`include "sram_define.sv"
`include "axi4_define.sv"

module mem_ctrl (
    axi4_if.slave axi4,
    sram_if.slave sram
);

  logic s_aw_hdshk, s_w_hdshk, s_b_hdshk, s_ar_hdshk, s_r_hdshk;
  logic s_wr_sel_d, s_wr_sel_q, s_arb_en;
  logic s_r_valid_en_d, s_r_valid_en_q;
  logic [`AXI4_ID_WIDTH-1:0] s_ar_id_d, s_ar_id_q;
  logic s_w_ready_d, s_w_ready_q;
  logic [`AXI4_ID_WIDTH-1:0] s_b_id_d, s_b_id_q;
  logic s_b_valid_d, s_b_valid_q;
  logic [`AXI4_ID_WIDTH-1:0] s_r_id_d, s_r_id_q;
  logic s_r_last_d, s_r_last_q;
  logic s_r_valid_d, s_r_valid_q;
  logic s_w_last, s_aw_valid, s_aw_ready;
  logic s_r_last, s_ar_valid, s_ar_ready;
  logic [`AXI4_ADDR_WIDTH-1:0] s_aw_addr, s_ar_addr;

  assign s_aw_hdshk  = axi4.awvalid & axi4.awready;
  assign s_w_hdshk   = axi4.wvalid & axi4.wready;
  assign s_b_hdshk   = axi4.bvalid & axi4.bready;
  assign s_ar_hdshk  = axi4.arvalid & axi4.arready;
  assign s_r_hdshk   = axi4.rvalid & axi4.rready;

  assign s_aw_ready  = (s_w_hdshk & ~s_w_last) | s_b_hdshk;
  assign s_ar_ready  = ~sram.en_i & ~s_wr_sel_q;

  assign axi4.wready = s_w_ready_q;
  assign axi4.bid    = s_b_id_q;
  assign axi4.bresp  = `AXI4_RESP_OKAY;
  assign axi4.buser  = '0;
  assign axi4.bvalid = s_b_valid_q;

  assign axi4.rid    = s_r_id_q;
  assign axi4.rdata  = sram.dat_o;
  assign axi4.rresp  = `AXI4_RESP_OKAY;
  assign axi4.rlast  = s_r_last_q;
  assign axi4.ruser  = '0;
  assign axi4.rvalid = s_r_valid_q;


  // sram slave if
  assign sram.clk_i  = axi4.aclk;
  assign sram.wen_i  = ~s_wr_sel_q;
  assign sram.bm_i   = ~(axi4.wstrb &{`AXI4_WSTRB_WIDTH{s_wr_sel_q}});
  assign sram.addr_i = s_wr_sel_q ? s_aw_addr : s_ar_addr;
  assign sram.dat_i  = axi4.wdata;
  always_comb begin
    sram.en_i = 1'b1;
    if(~s_wr_sel_q & s_ar_valid & ~(axi4.rvalid & axi4.rlast) & ~(axi4.rvalid & ~axi4.rready)) begin
      sram.en_i = 1'b0;
    end else if (s_w_hdshk) begin
      sram.en_i = 1'b0;
    end
  end

  always_comb begin
    s_arb_en = 1'b0;
    if (s_wr_sel_q & (~s_aw_valid | (s_w_last & s_aw_ready))) begin
      s_arb_en = 1'b1;
    end else if (~s_wr_sel_q & ~s_r_valid_en_q) begin
      s_arb_en = 1'b1;
    end
  end
  always_comb begin
    s_wr_sel_d = 1'b0;
    unique case ({
      s_aw_valid & axi4.wvalid, s_ar_valid
    })
      2'b00: s_wr_sel_d = s_wr_sel_q;
      2'b01: s_wr_sel_d = 1'b0;
      2'b10: s_wr_sel_d = 1'b1;
      2'b11: s_wr_sel_d = ~s_wr_sel_q;
    endcase
  end
  dffer #(1) u_wr_sel_dffer (
      axi4.aclk,
      axi4.aresetn,
      s_arb_en,
      s_wr_sel_d,
      s_wr_sel_q
  );

  assign s_w_ready_d = (s_wr_sel_q | (s_wr_sel_d & s_arb_en)) & s_aw_valid & ~(s_w_hdshk & axi4.wlast) & ~axi4.bvalid;
  dffr #(1) u_w_ready_dffr (
      axi4.aclk,
      axi4.aresetn,
      s_w_ready_d,
      s_w_ready_q
  );

  assign s_b_id_d = s_aw_hdshk ? axi4.awid : s_b_id_q;
  dffr #(`AXI4_ID_WIDTH) u_b_id_dffr (
      axi4.aclk,
      axi4.aresetn,
      s_b_id_d,
      s_b_id_q
  );

  assign s_b_valid_d = (s_w_hdshk & axi4.wlast) ? 1'b1 : (axi4.bready ? 1'b0 : s_b_valid_q);
  dffr #(1) u_b_valid_dffr (
      axi4.aclk,
      axi4.aresetn,
      s_b_valid_d,
      s_b_valid_q
  );

  assign s_ar_id_d = s_ar_hdshk ? axi4.arid : s_ar_id_q;
  dffr #(`AXI4_ID_WIDTH) u_ar_id_dffr (
      axi4.aclk,
      axi4.aresetn,
      s_ar_id_d,
      s_ar_id_q
  );

  assign s_r_id_d = s_ar_valid ? s_ar_id_q : s_r_id_q;
  dffr #(`AXI4_ID_WIDTH) u_r_id_dffr (
      axi4.aclk,
      axi4.aresetn,
      s_r_id_d,
      s_r_id_q
  );

  assign s_r_last_d = ~sram.en_i & s_ar_valid ? s_r_last : s_r_last_q;
  dffr #(1) u_r_last_dffr (
      axi4.aclk,
      axi4.aresetn,
      s_r_last_d,
      s_r_last_q
  );


  assign s_r_valid_en_d = (~sram.en_i & s_ar_valid & ~s_wr_sel_q) ? 1'b1: (s_r_hdshk ? 1'b0: s_r_valid_en_q);
  dffr #(1) u_r_valid_en_dffr (
      axi4.aclk,
      axi4.aresetn,
      s_r_valid_en_d,
      s_r_valid_en_q
  );

  assign s_r_valid_d = s_r_valid_en_q | (axi4.rvalid & ~axi4.rready);
  dffr #(1) u_r_valid_dffr (
      axi4.aclk,
      axi4.aresetn,
      s_r_valid_d,
      s_r_valid_q
  );


  addr_ctrl u_wr_addr_ctrl (
      .aclk_i      (axi4.aclk),
      .aresetn_i   (axi4.aresetn),
      .addr_i      (axi4.awaddr),
      .asize_i     (axi4.awsize),
      .aburst_i    (axi4.awburst),
      .alen_i      (axi4.awlen),
      .avalid_i    (axi4.awvalid),
      .aready_o    (axi4.awready),
      .addr_o      (s_aw_addr),
      .addr_last_o (s_w_last),
      .addr_valid_o(s_aw_valid),
      .addr_ready_i(s_aw_ready)
  );


  addr_ctrl u_rd_addr_ctrl (
      .aclk_i      (axi4.aclk),
      .aresetn_i   (axi4.aresetn),
      .addr_i      (axi4.araddr),
      .asize_i     (axi4.arsize),
      .aburst_i    (axi4.arburst),
      .alen_i      (axi4.arlen),
      .avalid_i    (axi4.arvalid),
      .aready_o    (axi4.arready),
      .addr_o      (s_ar_addr),
      .addr_last_o (s_r_last),
      .addr_valid_o(s_ar_valid),
      .addr_ready_i(s_ar_ready)
  );
endmodule
