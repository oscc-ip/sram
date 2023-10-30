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
// Copyright (c) 2023 Beijing Institute of Open Source Chip
// sram is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

module axi4_sram #(
    parameter int AXI_ADDR_WIDTH  = 32,
    parameter int AXI_DATA_WIDTH  = 64,
    parameter int AXI_ID_WIDTH    = 4,
    parameter int AXI_USER_WIDTH  = 4,
    parameter int SRAM_BLOCK_SIZE = 4    // each sram block size is 4KB
) (
    // verilog_format: off
    axi4_if.slave                        axi4
    // verilog_format: on
    // output logic                        en_o,
    // output logic                        wen_o,
    // output logic [AXI_DATA_WIDTH/8-1:0] bm_o,
    // output logic [  AXI_ADDR_WIDTH-1:0] addr_o,
    // input  logic [  AXI_DATA_WIDTH-1:0] dat_i,
    // output logic [  AXI_DATA_WIDTH-1:0] dat_o
);

  // AXI has the following rules governing the use of bursts:
  // - for wrapping bursts, the burst length must be 2, 4, 8, or 16
  // - a burst must not cross a 4KB address boundary
  // - early termination of bursts is not supported.
  typedef enum logic [1:0] {
    FIXED = 2'b00,
    INCR  = 2'b01,
    WRAP  = 2'b10
  } axi_burst_t;

  localparam LOG_NR_BYTES = $clog2(AXI_DATA_WIDTH / 8);

  typedef struct packed {
    logic [AXI_ID_WIDTH-1:0]   id;
    logic [AXI_ADDR_WIDTH-1:0] addr;
    logic [7:0]                len;
    logic [2:0]                size;
    axi_burst_t                burst;
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
  logic [AXI_ADDR_WIDTH-1:0] s_req_addr_d, s_req_addr_q;
  logic [7:0] s_cnt_d, s_cnt_q;

  function automatic logic [AXI_ADDR_WIDTH-1:0] get_wrap_boundary(
      input logic [AXI_ADDR_WIDTH-1:0] unaligned_address, input logic [7:0] len);
    logic [AXI_ADDR_WIDTH-1:0] warp_address = '0;
    //  for wrapping transfers ax_len can only be of size 1, 3, 7 or 15
    if (len == 4'b1) begin
      warp_address[AXI_ADDR_WIDTH-1:1+LOG_NR_BYTES] = unaligned_address[AXI_ADDR_WIDTH-1:1+LOG_NR_BYTES];
    end else if (len == 4'b11) begin
      warp_address[AXI_ADDR_WIDTH-1:2+LOG_NR_BYTES] = unaligned_address[AXI_ADDR_WIDTH-1:2+LOG_NR_BYTES];
    end else if (len == 4'b111) begin
      warp_address[AXI_ADDR_WIDTH-1:3+LOG_NR_BYTES] = unaligned_address[AXI_ADDR_WIDTH-3:2+LOG_NR_BYTES];
    end else if (len == 4'b1111) begin
      warp_address[AXI_ADDR_WIDTH-1:4+LOG_NR_BYTES] = unaligned_address[AXI_ADDR_WIDTH-3:4+LOG_NR_BYTES];
    end

    return warp_address;
  endfunction

  logic [AXI_ADDR_WIDTH-1:0] aligned_address;
  logic [AXI_ADDR_WIDTH-1:0] wrap_boundary;
  logic [AXI_ADDR_WIDTH-1:0] upper_wrap_boundary;
  logic [AXI_ADDR_WIDTH-1:0] cons_addr;

  always_comb begin
    // address generation
    aligned_address = {s_axi_req_q.addr[AXI_ADDR_WIDTH-1:LOG_NR_BYTES], {{LOG_NR_BYTES} {1'b0}}};
    wrap_boundary = get_wrap_boundary(s_axi_req_q.addr, s_axi_req_q.len);
    // this will overflow
    upper_wrap_boundary = wrap_boundary + ((s_axi_req_q.len + 1) << LOG_NR_BYTES);
    // calculate consecutive address
    cons_addr = aligned_address + (s_cnt_q << LOG_NR_BYTES);

    // Transaction attributes
    // default assignments
    s_state_d = s_state_q;
    s_axi_req_d = s_axi_req_q;
    s_req_addr_d = s_req_addr_q;
    s_cnt_d = s_cnt_q;
    // sram
    dat_o = axi4.w_data;
    bm_o = axi4.w_strb;
    wen_o = 1'b0;
    en_o = 1'b0;
    addr_o = '0;
    // axi4 request
    axi4.aw_ready = 1'b0;
    axi4.ar_ready = 1'b0;
    // axi4 read
    axi4.r_valid = 1'b0;
    axi4.r_data = dat_i;
    axi4.r_resp = '0;
    axi4.r_last = '0;
    axi4.r_id = s_axi_req_q.id;
    axi4.r_user = 1'b0;
    // axi4 write
    axi4.w_ready = 1'b0;
    // axi4 response
    axi4.b_valid = 1'b0;
    axi4.b_resp = 1'b0;
    axi4.b_id = 1'b0;
    axi4.b_user = 1'b0;

    case (s_state_q)
      IDLE: begin
        if (axi4.ar_valid) begin
          axi4.ar_ready = 1'b1;
          s_axi_req_d   = {axi4.ar_id, axi4.ar_addr, axi4.ar_len, axi4.ar_size, axi4.ar_burst};
          s_state_d     = READ;
          //  we can request the first address, this saves us time
          en_o          = 1'b1;
          addr_o        = axi4.ar_addr;
          s_req_addr_d  = axi4.ar_addr;
          s_cnt_d       = 1;
        end else if (axi4.aw_valid) begin
          axi4.aw_ready = 1'b1;
          axi4.w_ready  = 1'b1;
          addr_o        = axi4.aw_addr;
          s_axi_req_d   = {axi4.aw_id, axi4.aw_addr, axi4.aw_len, axi4.aw_size, axi4.aw_burst};
          // we've got our first w_valid so start the write process
          if (axi4.w_valid) begin
            en_o      = 1'b1;
            wen_o     = 1'b1;
            s_state_d = (axi4.w_last) ? SEND_B : WRITE;
            s_cnt_d   = 1;
            // we still have to wait for the first w_valid to arrive
          end else s_state_d = WAIT_WVALID;
        end
      end

      // we are still missing a w_valid
      WAIT_WVALID: begin
        axi4.w_ready = 1'b1;
        addr_o       = s_axi_req_q.addr;
        // we can now make our first request
        if (axi4.w_valid) begin
          en_o      = 1'b1;
          wen_o     = 1'b1;
          s_state_d = (axi4.w_last) ? SEND_B : WRITE;
          s_cnt_d   = 1;
        end
      end

      READ: begin
        // keep request to memory high
        en_o         = 1'b1;
        addr_o       = s_req_addr_q;
        // send the response
        axi4.r_valid = 1'b1;
        axi4.r_data  = dat_i;
        axi4.r_id    = s_axi_req_q.id;
        axi4.r_last  = (s_cnt_q == s_axi_req_q.len + 1);

        // check that the master is ready, the axi4 must not wait on this
        if (axi4.r_ready) begin
          // handle the correct burst type
          case (s_axi_req_q.burst)
            FIXED, INCR: addr_o = cons_addr;
            WRAP: begin
              // check if the address reached warp boundary
              if (cons_addr == upper_wrap_boundary) begin
                addr_o = wrap_boundary;
                // address warped beyond boundary
              end else if (cons_addr > upper_wrap_boundary) begin
                addr_o = s_axi_req_q.addr + ((s_cnt_q - s_axi_req_q.len) << LOG_NR_BYTES);
                // we are still in the incremental regime
              end else begin
                addr_o = cons_addr;
              end
            end
          endcase
          // we need to change the address here for the upcoming request
          // we sent the last byte -> go back to idle
          if (axi4.r_last) begin
            s_state_d = IDLE;
            // we already got everything
            en_o      = 1'b0;
          end
          // save the request address for the next cycle
          s_req_addr_d = addr_o;
          // we can decrease the counter as the master has consumed the read data
          s_cnt_d      = s_cnt_q + 1;
        end
      end

      WRITE: begin
        axi4.w_ready = 1'b1;
        // consume a word here
        if (axi4.w_valid) begin
          en_o  = 1'b1;
          wen_o = 1'b1;
          // handle the correct burst type
          case (s_axi_req_q.burst)

            FIXED, INCR: addr_o = cons_addr;
            WRAP: begin
              // check if the address reached warp boundary
              if (cons_addr == upper_wrap_boundary) begin
                addr_o = wrap_boundary;
                // address warped beyond boundary
              end else if (cons_addr > upper_wrap_boundary) begin
                addr_o = s_axi_req_q.addr + ((s_cnt_q - s_axi_req_q.len) << LOG_NR_BYTES);
                // we are still in the incremental regime
              end else begin
                addr_o = cons_addr;
              end
            end
          endcase
          // save the request address for the next cycle
          s_req_addr_d = addr_o;
          // we can decrease the counter as the master has consumed the read data
          s_cnt_d      = s_cnt_q + 1;

          if (axi4.w_last) s_state_d = SEND_B;
        end
      end
      SEND_B: begin
        axi4.b_valid = 1'b1;
        axi4.b_id    = s_axi_req_q.id;
        if (axi4.b_ready) s_state_d = IDLE;
      end

    endcase
  end

  always_ff @(posedge axi4.aclk, negedge axi4.aresetn) begin
    if (~axi4.aresetn) begin
      s_state_q    <= IDLE;
      s_axi_req_q  <= '0;
      s_req_addr_q <= '0;
      s_cnt_q      <= '0;
    end else begin
      s_state_q    <= s_state_d;
      s_axi_req_q  <= s_axi_req_d;
      s_req_addr_q <= s_req_addr_d;
      s_cnt_q      <= s_cnt_d;
    end
  end

  // decode and mux


  // 4KB fast regfile sram
  tech_regfile_bm #(
      .BIT_WIDTH (64),
      .WORD_DEPTH(512)
  ) u_tech_regile_bm (
      .clk_i(axi4.aclk)
  );
endmodule