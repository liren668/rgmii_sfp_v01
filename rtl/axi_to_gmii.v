//----------------------------------------------------------------------------------------
// File name:           axi_to_gmii
// Created by:          珊瑚伊斯特
// Created date:        2025.3
// Version:             V0.1
// Descriptions:        axi to gmii，三缓冲存储器结构。确保gmii_txd连续输出。
//
//----------------------------------------------------------------------------------------

module axi_to_gmii(
    // input                dclk,           // 调试用 100MHz时钟
    input                rst_n,          // 复位信号，低电平有效
    
    // AXI Stream 接口 (156.25MHz)
    input                tx_clk_out,     // AXI时钟域写时钟
    input                axis_tvalid,    // AXI数据有效信号
    input        [63:0]  axis_tdata,     // AXI数据
    input                axis_tlast,     // 包结束标志
    input        [7:0]   axis_tkeep,     // 字节有效掩码
    
    // GMII 接口 (125MHz)
    input                gmii_tx_clk,    // GMII时钟域读时钟
    output reg           gmii_tx_en,     // GMII发送数据有效
    output reg  [7:0]    gmii_txd        // GMII发送数据
);

// ==================== 写时钟域(156.25MHz) ====================
reg [63:0] buffer [0:2];        // 三缓冲存储器
reg [7:0]  keep_buffer [0:2];   // 保存tkeep信息
reg        last_buffer [0:2];   // 保存tlast信息
reg        data_valid [0:2];    // 缓冲区数据有效标志
reg [1:0]  wr_buf_sel;          // 写缓冲选择

// 添加握手信号
reg [2:0] clear_valid_req;     // 读时钟域请求清除valid
(* ASYNC_REG = "TRUE" *) reg [2:0] clear_valid_req_sync1, clear_valid_req_sync2;  // 同步到写时钟域

// 写控制逻辑
always @(posedge tx_clk_out or negedge rst_n) begin
    if (!rst_n) begin
        wr_buf_sel <= 2'd0;
        buffer[0] <= 64'd0;
        buffer[1] <= 64'd0;
        buffer[2] <= 64'd0;
        keep_buffer[0] <= 8'h0;
        keep_buffer[1] <= 8'h0;
        keep_buffer[2] <= 8'h0;
        last_buffer[0] <= 1'b0;
        last_buffer[1] <= 1'b0;
        last_buffer[2] <= 1'b0;
        data_valid[0] <= 1'b0;
        data_valid[1] <= 1'b0;
        data_valid[2] <= 1'b0;
        clear_valid_req_sync1 <= 3'b0;
        clear_valid_req_sync2 <= 3'b0;
    end else begin
        // 同步clear_valid_req信号
        clear_valid_req_sync1 <= clear_valid_req;
        clear_valid_req_sync2 <= clear_valid_req_sync1;
        
        // 根据同步后的请求清除valid（展开for循环）
        if(clear_valid_req_sync2[0]) data_valid[0] <= 1'b0;
        if(clear_valid_req_sync2[1]) data_valid[1] <= 1'b0;
        if(clear_valid_req_sync2[2]) data_valid[2] <= 1'b0;
        
        if (axis_tvalid) begin
            // 数据写入当前缓冲区
            buffer[wr_buf_sel] <= axis_tdata;
            keep_buffer[wr_buf_sel] <= axis_tkeep;
            last_buffer[wr_buf_sel] <= axis_tlast;
            data_valid[wr_buf_sel] <= 1'b1;  // 写完立即置位valid
            // 切换缓冲区
            wr_buf_sel <= (wr_buf_sel == 2'd2) ? 2'd0 : wr_buf_sel + 1'b1;
        end
    end
end

// 同步寄存器
(* ASYNC_REG = "TRUE" *) reg sync_data_valid_stage[2:0];
always @(posedge gmii_tx_clk or negedge rst_n) begin
    if (!rst_n) begin
        sync_data_valid_stage[0] <= 1'b0;
        sync_data_valid_stage[1] <= 1'b0;
        sync_data_valid_stage[2] <= 1'b0;
    end else begin
        // 对每一位进行双寄存器同步
        sync_data_valid_stage[0] <= data_valid[0];
        sync_data_valid_stage[1] <= data_valid[1];
        sync_data_valid_stage[2] <= data_valid[2];
    end
end

// 将同步后的信号组合成一个新的信号
wire [2:0] sync_data_valid = {sync_data_valid_stage[2], sync_data_valid_stage[1], sync_data_valid_stage[0]};

// ==================== 读时钟域(125MHz) ====================
reg [2:0]  rd_cnt;             // 字节计数器(0-7)
reg [1:0]  rd_buf_sel;         // 读缓冲选择
reg [63:0] rd_data;            // 读数据寄存器
reg [7:0]  rd_keep;            // 读keep寄存器
reg        rd_last;            // 读last寄存器
reg [1:0]  valid_data_count;   // 有效数据计数器
reg        packet_sending;     // 数据包发送中标志

// 有效数据计数器控制
always @(posedge gmii_tx_clk or negedge rst_n) begin
    if (!rst_n) begin
        valid_data_count <= 2'd0;
    end else begin
        // 更新有效数据计数
        case (sync_data_valid)
            3'b000: valid_data_count <= 2'd0;
            3'b001, 3'b010, 3'b100: valid_data_count <= 2'd1;
            3'b011, 3'b101, 3'b110: valid_data_count <= 2'd2;
            3'b111: valid_data_count <= 2'd3;
        endcase
    end
end

// 修改读控制逻辑部分
always @(posedge gmii_tx_clk or negedge rst_n) begin
    if (!rst_n) begin
        rd_cnt <= 3'd0;
        rd_buf_sel <= 2'd0;
        rd_data <= 64'd0;
        rd_keep <= 8'h0;
        rd_last <= 1'b0;
        packet_sending <= 1'b0;
        gmii_tx_en <= 1'b0;
        gmii_txd <= 8'd0;
        clear_valid_req <= 3'b0;
    end else begin
        // 数据包发送启动逻辑
        if (!packet_sending && valid_data_count >= 2'd2) begin
            packet_sending <= 1'b1;
            rd_data <= buffer[rd_buf_sel];
            rd_keep <= keep_buffer[rd_buf_sel];
            rd_last <= last_buffer[rd_buf_sel];
            clear_valid_req[rd_buf_sel] <= 1'b1;  // 请求清除valid
            rd_cnt <= 3'd0;
            rd_buf_sel <= (rd_buf_sel == 2'd2) ? 2'd0 : rd_buf_sel + 1'b1;
        end else begin
            clear_valid_req <= 3'b0;  // 清除请求
        end

        // 数据发送逻辑
        if (packet_sending) begin
            // 数据输出，根据rd_keep判断是否输出有效数据
            case (rd_cnt)
                3'd0: begin
                    gmii_txd <= rd_data[7:0];
                    gmii_tx_en <= rd_keep[0];
                end
                3'd1: begin
                    gmii_txd <= rd_data[15:8];
                    gmii_tx_en <= rd_keep[1];
                end
                3'd2: begin
                    gmii_txd <= rd_data[23:16];
                    gmii_tx_en <= rd_keep[2];
                end
                3'd3: begin
                    gmii_txd <= rd_data[31:24];
                    gmii_tx_en <= rd_keep[3];
                end
                3'd4: begin
                    gmii_txd <= rd_data[39:32];
                    gmii_tx_en <= rd_keep[4];
                end
                3'd5: begin
                    gmii_txd <= rd_data[47:40];
                    gmii_tx_en <= rd_keep[5];
                end
                3'd6: begin
                    gmii_txd <= rd_data[55:48];
                    gmii_tx_en <= rd_keep[6];
                end
                3'd7: begin 
                    gmii_txd <= rd_data[63:56];
                    gmii_tx_en <= rd_keep[7];
                    
                    // 提前一个周期准备下一组数据
                    if (!rd_last && sync_data_valid[rd_buf_sel]) begin
                        rd_data <= buffer[rd_buf_sel];
                        rd_keep <= keep_buffer[rd_buf_sel];
                        rd_last <= last_buffer[rd_buf_sel];
                        clear_valid_req[rd_buf_sel] <= 1'b1;  // 请求清除valid
                        rd_buf_sel <= (rd_buf_sel == 2'd2) ? 2'd0 : rd_buf_sel + 1'b1;
                    end
                end
            endcase

            // 计数器控制
            if (rd_cnt == 3'd7) begin
                if (rd_last || !rd_keep[7]) begin
                    packet_sending <= 1'b0;
                end
                rd_cnt <= 3'd0;
            end else begin
                if (rd_last && !rd_keep[rd_cnt]) begin
                    // 如果是最后一个数据包且当前字节无效，结束发送
                    packet_sending <= 1'b0;
                end
                rd_cnt <= rd_cnt + 1'b1;
            end
            
        end else begin
            gmii_tx_en <= 1'b0;
            gmii_txd <= 8'd0;
        end
    end
end

endmodule