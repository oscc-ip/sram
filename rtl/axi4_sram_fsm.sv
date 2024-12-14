// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// -- Adaptable modifications are redistributed under compatible License --
//
// Copyright (c) 2023-2024 Miao Yuchi <miaoyuchi@ict.ac.cn>
// sram is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

`include "regfile.sv"
`include "register.sv"
`include "axi4_define.sv"

// each sram block capacity is 4KB
module axi4_sram_fsm #(
    parameter int SRAM_WORD_DEPTH = 512,
    parameter int SRAM_BLOCK_SIZE = 4
) (
    axi4_if.slave axi4
);
  // verilog_format: off
  localparam int SRAM_BIT_WIDTH         = `AXI4_DATA_WIDTH;
  localparam int SRAM_ADDR_WDITH        = $clog2(SRAM_WORD_DEPTH);
  localparam int SRAM_HIGH_BOUND        = `AXI4_DATA_BLOG + SRAM_ADDR_WDITH;
  localparam int SRAM_BLOCK_BYTES_WIDTH = $clog2(SRAM_WORD_DEPTH * SRAM_BIT_WIDTH / 8);
  // verilog_format: on

  logic                         s_ram_en;
  logic                         s_ram_wen;
  logic [  SRAM_ADDR_WDITH-1:0] s_ram_addr;
  logic [`AXI4_WSTRB_WIDTH-1:0] s_ram_bm;
  logic [ `AXI4_DATA_WIDTH-1:0] s_ram_dat_i;
  logic [ `AXI4_DATA_WIDTH-1:0] s_ram_dat_o;

  // AXI has the following rules governing the use of bursts:
  // - a burst must not cross a 4KB address boundary
  typedef enum logic [1:0] {
    FIXED = 2'b00,
    INCR  = 2'b01,
    WRAP  = 2'b10
  } axi_burst_t;

  typedef struct packed {
    logic [`AXI4_ID_WIDTH-1:0]   id;
    logic [`AXI4_ADDR_WIDTH-1:0] addr;
    logic [7:0]                  len;
    logic [2:0]                  size;
    axi_burst_t                  burst;
  } axi_req_t;

  typedef enum logic [2:0] {
    IDLE,
    READ,
    WRITE,
    SEND_B,
    WAIT_WVALID
  } axi_fsm_t;

  axi_req_t s_axi_req_d, s_axi_req_q;
  axi_fsm_t s_state_d, s_state_q;
  logic [7:0] s_trans_cnt_d, s_trans_cnt_q;
  logic [`AXI4_ADDR_WIDTH-1:0] s_sram_idx_addr_d, s_sram_idx_addr_q;
  logic [    `AXI4_ADDR_WIDTH-1:0] s_trans_nxt_addr;
  logic [`AXI4_ADDR_OFT_WIDTH-1:0] s_oft_addr;

  assign s_trans_nxt_addr = {s_axi_req_q.addr[`AXI4_ADDR_WIDTH-1:`AXI4_ADDR_OFT_WIDTH], s_oft_addr};
  addr_gen u_addr_gen (
      .alen_i  (s_axi_req_q.len),
      .asize_i (s_axi_req_q.size),
      .aburst_i(s_axi_req_q.burst),
      .addr_i  (s_axi_req_q.addr[`AXI4_ADDR_OFT_WIDTH-1:0]),
      .addr_o  (s_oft_addr)
  );

  always_comb begin
    s_state_d         = s_state_q;
    s_axi_req_d       = s_axi_req_q;
    s_axi_req_d.addr  = s_trans_nxt_addr;
    s_trans_cnt_d     = s_trans_cnt_q;
    s_sram_idx_addr_d = s_sram_idx_addr_q;
    // sram
    s_ram_dat_o       = axi4.wdata;
    s_ram_bm          = axi4.wstrb;
    s_ram_wen         = 1'b0;
    s_ram_en          = 1'b0;
    s_ram_addr        = '0;
    // axi4 request
    axi4.awready      = 1'b0;
    axi4.arready      = 1'b0;
    // axi4 read
    axi4.rvalid       = 1'b0;
    axi4.rdata        = s_ram_dat_i;
    axi4.rresp        = '0;
    axi4.rlast        = '0;
    axi4.rid          = s_axi_req_q.id;
    axi4.ruser        = 1'b0;
    // axi4 write
    axi4.wready       = 1'b0;
    // axi4 response
    axi4.bvalid       = 1'b0;
    axi4.bresp        = 1'b0;
    axi4.bid          = 1'b0;
    axi4.buser        = 1'b0;

    case (s_state_q)
      IDLE: begin
        if (axi4.arvalid) begin
          axi4.arready      = 1'b1;
          s_axi_req_d       = {axi4.arid, axi4.araddr, axi4.arlen, axi4.arsize, axi4.arburst};
          s_state_d         = READ;
          //  we can request the first address, this saves us time
          s_ram_en          = 1'b1;
          s_ram_addr        = axi4.araddr[SRAM_HIGH_BOUND-1:3];
          s_sram_idx_addr_d = axi4.araddr;
          s_trans_cnt_d     = 1;
        end else if (axi4.awvalid) begin
          axi4.awready      = 1'b1;
          axi4.wready       = 1'b1;
          s_axi_req_d       = {axi4.awid, axi4.awaddr, axi4.awlen, axi4.awsize, axi4.awburst};
          s_ram_addr        = axi4.awaddr[SRAM_HIGH_BOUND-1:3];
          s_sram_idx_addr_d = axi4.awaddr;
          // we've got our first wvalid so start the write process
          if (axi4.wvalid) begin
            s_ram_en      = 1'b1;
            s_ram_wen     = 1'b1;

            s_state_d     = (axi4.wlast) ? SEND_B : WRITE;
            s_trans_cnt_d = 1;
            // we still have to wait for the first wvalid to arrive
          end else s_state_d = WAIT_WVALID;
        end
      end

      // we are still missing a wvalid
      WAIT_WVALID: begin
        axi4.wready = 1'b1;
        s_ram_addr  = s_axi_req_q.addr[SRAM_HIGH_BOUND-1:3];
        // we can now make our first request
        if (axi4.wvalid) begin
          s_ram_en      = 1'b1;
          s_ram_wen     = 1'b1;
          s_state_d     = (axi4.wlast) ? SEND_B : WRITE;
          s_trans_cnt_d = 1;
        end
      end

      READ: begin
        // keep request to memory high
        s_ram_en    = 1'b1;
        s_ram_addr  = s_axi_req_q.addr[SRAM_HIGH_BOUND-1:3];
        // send the response
        axi4.rvalid = 1'b1;
        axi4.rdata  = s_ram_dat_i;
        axi4.rid    = s_axi_req_q.id;
        axi4.rlast  = (s_trans_cnt_q == s_axi_req_q.len + 1);

        // check that the master is ready, the axi4 must not wait on this
        if (axi4.rready) begin
          // handle the correct burst type
          case (s_axi_req_q.burst)
            FIXED, INCR: s_ram_addr = s_axi_req_q.addr[SRAM_HIGH_BOUND-1:3];
            default:     s_ram_addr = '0;
          endcase
          // we need to change the address here for the upcoming request
          // we sent the last byte -> go back to idle
          if (axi4.rlast) begin
            s_state_d = IDLE;
            // we already got everything
            s_ram_en  = 1'b0;
          end
          // we can decrease the counter as the master has consumed the read data
          s_trans_cnt_d = s_trans_cnt_q + 1;
        end
      end

      WRITE: begin
        axi4.wready = 1'b1;
        // consume a word here
        if (axi4.wvalid) begin
          s_ram_en  = 1'b1;
          s_ram_wen = 1'b1;
          // handle the correct burst type
          case (s_axi_req_q.burst)
            FIXED, INCR: s_ram_addr = s_axi_req_q.addr[SRAM_HIGH_BOUND-1:3];
            default:     s_ram_addr = '0;
          endcase
          // we can decrease the counter as the master has consumed the read data
          s_trans_cnt_d = s_trans_cnt_q + 1;

          if (axi4.wlast) s_state_d = SEND_B;
        end
      end
      SEND_B: begin
        axi4.bvalid = 1'b1;
        axi4.bid    = s_axi_req_q.id;
        if (axi4.bready) s_state_d = IDLE;
      end
    endcase
  end

  dffr #(`AXI4_ADDR_WIDTH) u_sram_idx_addr_dffr (
      axi4.aclk,
      axi4.aresetn,
      s_sram_idx_addr_d,
      s_sram_idx_addr_q
  );

  dffr #(8) u_cnt_dffr (
      axi4.aclk,
      axi4.aresetn,
      s_trans_cnt_d,
      s_trans_cnt_q
  );

  always_ff @(posedge axi4.aclk, negedge axi4.aresetn) begin
    if (~axi4.aresetn) begin
      s_state_q   <= #1 IDLE;
      s_axi_req_q <= #1'0;
    end else begin
      s_state_q   <= #1 s_state_d;
      s_axi_req_q <= #1 s_axi_req_d;
    end
  end

  // decode and mux
  logic [       `AXI4_ADDR_WIDTH-1:0]                              s_axi_addr;
  logic [$clog2(SRAM_BLOCK_SIZE)-1:0]                              s_tech_sram_idx;
  logic [        SRAM_BLOCK_SIZE-1:0]                              s_tech_sram_en;
  logic [        SRAM_BLOCK_SIZE-1:0]                              s_tech_sram_wen;
  logic [        SRAM_BLOCK_SIZE-1:0][       SRAM_BIT_WIDTH/8-1:0] s_tech_sram_bm;
  logic [        SRAM_BLOCK_SIZE-1:0][$clog2(SRAM_WORD_DEPTH)-1:0] s_tech_sram_addr;
  logic [        SRAM_BLOCK_SIZE-1:0][         SRAM_BIT_WIDTH-1:0] s_tech_sram_dat_i;
  logic [        SRAM_BLOCK_SIZE-1:0][         SRAM_BIT_WIDTH-1:0] s_tech_sram_dat_o;

  always_comb begin
    s_axi_addr = '0;
    if (axi4.arvalid && axi4.arready) begin
      s_axi_addr = axi4.araddr;
    end else if (axi4.awvalid && axi4.awready) begin
      s_axi_addr = axi4.awaddr;
    end else begin
      s_axi_addr = s_sram_idx_addr_q;
    end
  end

  // split the addr into 4KB
  assign s_tech_sram_idx = s_axi_addr[SRAM_BLOCK_BYTES_WIDTH+:$clog2(SRAM_BLOCK_SIZE)];
  always_comb begin
    s_tech_sram_en                     = '0;
    s_tech_sram_wen                    = '0;
    s_tech_sram_bm                     = '0;
    s_tech_sram_addr                   = '0;
    s_tech_sram_dat_i                  = '0;
    s_tech_sram_en[s_tech_sram_idx]    = s_ram_en;
    s_tech_sram_wen[s_tech_sram_idx]   = s_ram_wen;
    s_tech_sram_bm[s_tech_sram_idx]    = s_ram_bm;
    s_tech_sram_addr[s_tech_sram_idx]  = s_ram_addr;
    s_tech_sram_dat_i[s_tech_sram_idx] = s_ram_dat_o;
    s_ram_dat_i                        = s_tech_sram_dat_o[s_tech_sram_idx];
  end

  for (genvar i = 0; i < SRAM_BLOCK_SIZE; i++) begin
    // 4KB fast regfile sram
    tech_regfile_bm #(
        .BIT_WIDTH (SRAM_BIT_WIDTH),
        .WORD_DEPTH(SRAM_WORD_DEPTH)
    ) u_tech_regile_bm (
        .clk_i (axi4.aclk),
        .en_i  (~s_tech_sram_en[i]),
        .wen_i (~s_tech_sram_wen[i]),
        .bm_i  (~s_tech_sram_bm[i]),
        .addr_i(s_tech_sram_addr[i]),
        .dat_i (s_tech_sram_dat_i[i]),
        .dat_o (s_tech_sram_dat_o[i])
    );
  end

endmodule
