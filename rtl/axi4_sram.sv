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

// each sram block capacity is 4KB
module axi4_sram #(
    parameter int          AXI_ADDR_WIDTH  = 32,
    parameter int          AXI_DATA_WIDTH  = 64,
    parameter int          AXI_ID_WIDTH    = 4,
    parameter int          AXI_USER_WIDTH  = 4,
    parameter int          SRAM_BIT_WIDTH  = 64,
    parameter int          SRAM_WORD_DEPTH = 512,
    parameter int          SRAM_BLOCK_SIZE = 4,
    parameter int unsigned SRAM_BASE_ADDR  = 32'h0F00_0000
) (
    axi4_if.slave axi4
);

  logic                        s_ram_en;
  logic                        s_ram_wen;
  logic [AXI_DATA_WIDTH/8-1:0] s_ram_bm;
  logic [  AXI_ADDR_WIDTH-1:0] s_ram_addr;
  logic [  AXI_DATA_WIDTH-1:0] s_ram_dat_i;
  logic [  AXI_DATA_WIDTH-1:0] s_ram_dat_o;

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

  logic [AXI_ADDR_WIDTH-1:0] aligned_addr;
  logic [AXI_ADDR_WIDTH-1:0] wrap_boundary;
  logic [AXI_ADDR_WIDTH-1:0] upper_wrap_boundary;
  logic [AXI_ADDR_WIDTH-1:0] cons_addr;

  always_comb begin
    // address generation
    aligned_addr = {s_axi_req_q.addr[AXI_ADDR_WIDTH-1:LOG_NR_BYTES], {{LOG_NR_BYTES} {1'b0}}};
    wrap_boundary = get_wrap_boundary(s_axi_req_q.addr, s_axi_req_q.len);
    // this will overflow
    upper_wrap_boundary = wrap_boundary + ((s_axi_req_q.len + 1) << LOG_NR_BYTES);
    // calculate consecutive address
    cons_addr = aligned_addr + (s_cnt_q << LOG_NR_BYTES);

    // transaction attributes
    s_state_d = s_state_q;
    s_axi_req_d = s_axi_req_q;
    s_req_addr_d = s_req_addr_q;
    s_cnt_d = s_cnt_q;
    // sram
    s_ram_dat_o = axi4.wdata;
    s_ram_bm = axi4.wstrb;
    s_ram_wen = 1'b0;
    s_ram_en = 1'b0;
    s_ram_addr = '0;
    // axi4 request
    axi4.awready = 1'b0;
    axi4.arready = 1'b0;
    // axi4 read
    axi4.rvalid = 1'b0;
    axi4.rdata = s_ram_dat_i;
    axi4.rresp = '0;
    axi4.rlast = '0;
    axi4.rid = s_axi_req_q.id;
    axi4.ruser = 1'b0;
    // axi4 write
    axi4.wready = 1'b0;
    // axi4 response
    axi4.bvalid = 1'b0;
    axi4.bresp = 1'b0;
    axi4.bid = 1'b0;
    axi4.buser = 1'b0;

    case (s_state_q)
      IDLE: begin
        if (axi4.arvalid) begin
          axi4.arready = 1'b1;
          s_axi_req_d  = {axi4.arid, axi4.araddr, axi4.arlen, axi4.arsize, axi4.arburst};
          s_state_d    = READ;
          //  we can request the first address, this saves us time
          s_ram_en     = 1'b1;
          s_ram_addr   = axi4.araddr;
          s_req_addr_d = axi4.araddr;
          s_cnt_d      = 1;
        end else if (axi4.awvalid) begin
          axi4.awready = 1'b1;
          axi4.wready  = 1'b1;
          s_axi_req_d  = {axi4.awid, axi4.awaddr, axi4.awlen, axi4.awsize, axi4.awburst};
          s_ram_addr   = axi4.awaddr;
          // we've got our first wvalid so start the write process
          if (axi4.wvalid) begin
            s_ram_en  = 1'b1;
            s_ram_wen = 1'b1;
            s_state_d = (axi4.wlast) ? SEND_B : WRITE;
            s_cnt_d   = 1;
            // we still have to wait for the first wvalid to arrive
          end else s_state_d = WAIT_WVALID;
        end
      end

      // we are still missing a wvalid
      WAIT_WVALID: begin
        axi4.wready = 1'b1;
        s_ram_addr  = s_axi_req_q.addr;
        // we can now make our first request
        if (axi4.wvalid) begin
          s_ram_en  = 1'b1;
          s_ram_wen = 1'b1;
          s_state_d = (axi4.wlast) ? SEND_B : WRITE;
          s_cnt_d   = 1;
        end
      end

      READ: begin
        // keep request to memory high
        s_ram_en    = 1'b1;
        s_ram_addr  = s_req_addr_q;
        // send the response
        axi4.rvalid = 1'b1;
        axi4.rdata  = s_ram_dat_i;
        axi4.rid    = s_axi_req_q.id;
        axi4.rlast  = (s_cnt_q == s_axi_req_q.len + 1);

        // check that the master is ready, the axi4 must not wait on this
        if (axi4.rready) begin
          // handle the correct burst type
          case (s_axi_req_q.burst)
            FIXED, INCR: s_ram_addr = cons_addr;
            WRAP: begin
              // check if the address reached warp boundary
              if (cons_addr == upper_wrap_boundary) begin
                s_ram_addr = wrap_boundary;
                // address warped beyond boundary
              end else if (cons_addr > upper_wrap_boundary) begin
                s_ram_addr = s_axi_req_q.addr + ((s_cnt_q - s_axi_req_q.len) << LOG_NR_BYTES);
                // we are still in the incremental regime
              end else begin
                s_ram_addr = cons_addr;
              end
            end
          endcase
          // we need to change the address here for the upcoming request
          // we sent the last byte -> go back to idle
          if (axi4.rlast) begin
            s_state_d = IDLE;
            // we already got everything
            s_ram_en  = 1'b0;
          end
          // save the request address for the next cycle
          s_req_addr_d = s_ram_addr;
          // we can decrease the counter as the master has consumed the read data
          s_cnt_d      = s_cnt_q + 1;
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
            FIXED, INCR: s_ram_addr = cons_addr;
            WRAP: begin
              // check if the address reached warp boundary
              if (cons_addr == upper_wrap_boundary) begin
                s_ram_addr = wrap_boundary;
                // address warped beyond boundary
              end else if (cons_addr > upper_wrap_boundary) begin
                s_ram_addr = s_axi_req_q.addr + ((s_cnt_q - s_axi_req_q.len) << LOG_NR_BYTES);
                // we are still in the incremental regime
              end else begin
                s_ram_addr = cons_addr;
              end
            end
          endcase
          // save the request address for the next cycle
          s_req_addr_d = s_ram_addr;
          // we can decrease the counter as the master has consumed the read data
          s_cnt_d      = s_cnt_q + 1;

          if (axi4.wlast) s_state_d = SEND_B;
        end
      end
      SEND_B: begin
        axi4.bvalid = 1'b1;
        axi4.bid    = s_axi_req_q.id;
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
  logic [         AXI_ADDR_WIDTH-1:0]                              s_axi_addr;
  logic [$clog2(SRAM_BLOCK_SIZE)-1:0]                              s_sram_idx;
  logic [        SRAM_BLOCK_SIZE-1:0]                              s_sram_en;
  logic [        SRAM_BLOCK_SIZE-1:0]                              s_sram_wen;
  logic [        SRAM_BLOCK_SIZE-1:0][       SRAM_BIT_WIDTH/8-1:0] s_sram_bm;
  logic [        SRAM_BLOCK_SIZE-1:0][$clog2(SRAM_WORD_DEPTH)-1:0] s_sram_addr;
  logic [        SRAM_BLOCK_SIZE-1:0][         SRAM_BIT_WIDTH-1:0] s_sram_dat_i;
  logic [        SRAM_BLOCK_SIZE-1:0][         SRAM_BIT_WIDTH-1:0] s_sram_dat_o;

  always_comb begin
    s_axi_addr = '0;
    if (axi4.arvalid && axi4.arready) begin
      s_axi_addr = axi4.araddr - `SRAM_BASE_ADDR;
    end else if (axi4.awvalid && axi4.awready) begin
      s_axi_addr = axi4.awaddr - `SRAM_BASE_ADDR;
    end
  end

  // split the addr into 4KB
  assign s_sram_idx = s_axi_addr[$clog2(
      SRAM_WORD_DEPTH*SRAM_BIT_WIDTH
  )+$clog2(
      SRAM_BLOCK_SIZE
  ):$clog2(
      SRAM_WORD_DEPTH*SRAM_BIT_WIDTH
  )];

  always_comb begin
    s_sram_en[s_sram_idx]    = s_ram_en;
    s_sram_wen[s_sram_idx]   = s_ram_wen;
    s_sram_bm[s_sram_idx]    = s_ram_bm;
    s_sram_addr[s_sram_idx]  = s_ram_addr;
    s_sram_dat_i[s_sram_idx] = s_ram_dat_o;
    s_sram_dat_o[s_sram_idx] = s_ram_dat_i;
  end

  for (genvar i = 0; i < SRAM_BLOCK_SIZE - 1; i++) begin
    // 4KB fast regfile sram
    tech_regfile_bm #(
        .BIT_WIDTH (SRAM_BIT_WIDTH),
        .WORD_DEPTH(SRAM_WORD_DEPTH)
    ) u_tech_regile_bm (
        .clk_i      (axi4.aclk),
        .en_i       (~s_sram_en[i]),
        .wen_i      (~s_sram_wen[i]),
        .bm_i       (s_sram_bm[i]),
        .addr_i     (s_sram_addr[i]),
        .s_ram_dat_i(s_sram_dat_i[i]),
        .s_ram_dat_o(s_sram_dat_o[i])
    );
  end

endmodule
