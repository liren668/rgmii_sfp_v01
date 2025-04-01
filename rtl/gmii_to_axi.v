//----------------------------------------------------------------------------------------
// File name:           gmii_to_axi
// Created by:          珊瑚伊斯特
// Created date:        2025.3
// Version:             V0.1
// Descriptions:        gmii_to_axi
//双缓冲GMII到AXI转换器，接收GMII数据8bit并转换为AXI64bit流格式
//----------------------------------------------------------------------------------------
module gmii_to_axi(
    input             clk_ila,       // ILA时钟
    input             gmii_rx_clk,    // 125MHz写时钟
    input             tx_clk_out,     // 156.25MHz读时钟
    input             rst_n,
    input             gmii_rx_dv,     // GMII数据有效
    input  [7:0]      gmii_rxd,       // GMII接收数据
    output reg        axis_tvalid,    // AXI有效信号
    output reg [63:0] axis_tdata,
    output reg        axis_tlast,     // 包结束标志
    output reg [7:0]  axis_tkeep,     // 字节有效掩码
    input             axis_tready     // 下游就绪信号
);

// ==================== 写时钟域逻辑（125MHz）====================
reg [63:0] buffer [0:1];        // 双缓冲存储器
reg        wr_buf_sel;          // 写缓冲选择（0/1）
reg [2:0]  wr_cnt;              // 字节计数器（0-7）
reg [2:0]  valid_bytes [0:1];   // 各缓冲有效字节数
reg        pkt_end [0:1];       // 包结束标志

//ILA实例化
ila_1 u_ila_1 (
    .clk(clk_ila),              // input wire clk
    .probe0(axis_tdata),         // input wire [63:0]  probe0  
    .probe1(axis_tkeep),        // input wire [7:0]  probe1 
    .probe2(tx_clk_out),        // input wire [0:0]  probe2 
    .probe3(axis_tlast),        // input wire [0:0]  probe3 
    .probe4(axis_tvalid),        // input wire [0:0]  probe4 
    .probe5(axis_tready),      // input wire [0:0]  probe5 
    .probe6(gmii_rxd),         // input wire [7:0]  probe6 
    .probe7(gmii_rx_dv),        // input wire [0:0]  probe7
    .probe8(sync_wr_buf_sel[1]),        // input wire [0:0]  probe7
    .probe9(sync_rd_buf_sel[1])        // input wire [0:0]  probe7
);

(* ASYNC_REG = "TRUE" *) reg [1:0] sync_rd_buf_sel; // 读指针同步链

// 写控制逻辑
always @(posedge gmii_rx_clk or negedge rst_n) begin
    if (!rst_n) begin
        wr_buf_sel <= 0;
        wr_cnt <= 0;
        buffer[0] <= 64'd0;
        buffer[1] <= 64'd0;
        valid_bytes[0] <= 3'd0;
        valid_bytes[1] <= 3'd0;
        pkt_end[0] <= 1'b0;
        pkt_end[1] <= 1'b0;
    end else begin
        if (gmii_rx_dv) begin
            // 数据填充
            buffer[wr_buf_sel][wr_cnt*8 +:8] <= gmii_rxd;    //第一个字节 (wr_cnt=0): 填充到 [7:0]
                                                             //第二个字节 (wr_cnt=1): 填充到 [15:8]
                                                             //第三个字节 (wr_cnt=2): 填充到 [23:16] ...以此类推                      
            if (wr_cnt == 3'd7) begin // 缓冲区写满
                valid_bytes[wr_buf_sel] <= 3'd0;  // 修改这里：0表示8个字节都有效
                pkt_end[wr_buf_sel] <= 1'b0;
                wr_cnt <= 0;
                // 无条件切换缓冲区，防止数据丢失
                wr_buf_sel <= ~wr_buf_sel;
            end else begin
                wr_cnt <= wr_cnt + 1;
            end
        end 
        else if (wr_cnt != 0) begin // 包结束处理
            valid_bytes[wr_buf_sel] <=  wr_cnt ;
            pkt_end[wr_buf_sel] <= 1'b1;
            wr_cnt <= 0;
            // 无条件切换缓冲区，防止数据丢失
            wr_buf_sel <= ~wr_buf_sel;
        end
    end
end

// ==================== 读时钟域逻辑（156.25MHz）====================
reg        rd_buf_sel;          // 读缓冲选择（0/1）
(* ASYNC_REG = "TRUE" *) reg [1:0] sync_wr_buf_sel; // 写指针同步链

always @(posedge tx_clk_out or negedge rst_n) begin
    if (!rst_n) begin
        rd_buf_sel <= 0;
        axis_tvalid <= 1'b0;
        axis_tdata <= 64'd0;
        axis_tlast <= 1'b0;
        axis_tkeep <= 8'h00;
    end else begin
        if (sync_wr_buf_sel[1] != sync_rd_buf_sel[1]) begin
            axis_tvalid <= 1'b1;  // 持续置高valid直到握手成功
            axis_tdata <= buffer[rd_buf_sel];
            axis_tlast <= pkt_end[rd_buf_sel];
            axis_tkeep <= calc_tkeep(valid_bytes[rd_buf_sel]);
            
            if (axis_tready) begin
                rd_buf_sel <= ~rd_buf_sel; // 仅当握手成功时切换缓冲区
            end
        end else begin
            axis_tvalid <= 1'b0;
        end
    end
end

// tkeep生成函数
function [7:0] calc_tkeep(input [2:0] bytes);
    case(bytes)
        3'd0: calc_tkeep = 8'hFF;    // 8个有效字节
        3'd1: calc_tkeep = 8'h01;    // 1个有效字节
        3'd2: calc_tkeep = 8'h03;    // 2个有效字节
        3'd3: calc_tkeep = 8'h07;    // 3个有效字节
        3'd4: calc_tkeep = 8'h0F;    // 4个有效字节
        3'd5: calc_tkeep = 8'h1F;    // 5个有效字节
        3'd6: calc_tkeep = 8'h3F;    // 6个有效字节
        3'd7: calc_tkeep = 8'h7F;    // 7个有效字节
        default: calc_tkeep = 8'hFF;  // 防止异常情况
    endcase
endfunction

// ==================== 跨时钟域同步 ====================
// 写指针同步到读时钟域
always @(posedge tx_clk_out) begin
    sync_wr_buf_sel[0] <= wr_buf_sel;
    sync_wr_buf_sel[1] <= sync_wr_buf_sel[0];
end

// 读指针同步到写时钟域
always @(posedge gmii_rx_clk) begin
    sync_rd_buf_sel[0] <= rd_buf_sel;
    sync_rd_buf_sel[1] <= sync_rd_buf_sel[0];
end

endmodule