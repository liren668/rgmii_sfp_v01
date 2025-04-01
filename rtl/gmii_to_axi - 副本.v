//----------------------------------------------------------------------------------------
// File name:           gmii_to_axi
// Created by:          珊瑚伊斯特
// Created date:        2025.3
// Version:             V0.1
// Descriptions:        gmii_to_axi
//
//----------------------------------------------------------------------------------------

module gmii_to_axi(
    input                gmii_rx_clk  ,  // RGMII接收时钟
    input                tx_clk_out   ,  // 发送时钟
    input                rst_n        ,  // 复位信号，低电平有效
    input                gmii_rx_dv   ,  // GMII接收数据有效信号
    input        [7:0]   gmii_rxd     ,  // GMII接收数据
    output  reg          axis_tvalid  ,  // AXI数据有效信号
    output  reg  [63:0]  axis_tdata   ,  // AXI数据
    output  reg          axis_tlast   ,  // AXI最后一个数据标志
    output  reg  [7:0]   axis_tkeep   ,  // AXI数据有效字节标志
    input                axis_tready     // AXI准备好接收信号
);

// 写时钟域寄存器
reg  [2:0]   wr_byte_cnt;   // 写时钟域字节计数器
reg          wr_dv_d0;      // 写时钟域dv延迟
reg          wr_last_data;  // 写时钟域最后数据标志
reg  [7:0]   wr_keep_reg;   // 写时钟域有效字节标志

// 读时钟域寄存器
reg          rd_valid;      // 读时钟域有效信号
reg          rd_last;       // 读时钟域最后数据标志
reg  [7:0]   rd_keep;       // 读时钟域有效字节标志

// FIFO控制信号
wire         fifo_wr_en;
// wire [7:0]   fifo_din;      // 8位输入
wire [63:0]  fifo_dout;     // 64位输出
wire         fifo_empty;     // FIFO空信号
reg          fifo_rd_en;    // FIFO读使能

// FIFO写控制
assign fifo_wr_en = gmii_rx_dv;  // 由于读时钟快于写时钟，无需检查FIFO满状态
assign fifo_din = gmii_rxd;

// FIFO实例化，FIFO_DEPTH = 256。
async_fifo_8to64 u_rx_async_fifo (
    .rst           (~rst_n),             //  复位信号
    .wr_clk        (gmii_rx_clk),         // 写时钟信号
    .wr_en         (fifo_wr_en),          // 写使能信号
    .din           (fifo_din),            // 写入8位数据
    .rd_clk        (tx_clk_out),          // 读时钟信号
    .rd_en         (fifo_rd_en),          // 读使能信号
    .dout          (fifo_dout),           // 读出64位数据
    .empty         (fifo_empty)           // FIFO空信号
);

// 写时钟域数据处理
always @(posedge gmii_rx_clk or negedge rst_n) begin
    if (!rst_n) begin
        wr_byte_cnt  <= 3'd0;
        wr_dv_d0     <= 1'b0;
        wr_last_data <= 1'b0;
        wr_keep_reg  <= 8'h00;
    end else begin
        wr_dv_d0 <= gmii_rx_dv;
        
        if (gmii_rx_dv) begin
            wr_byte_cnt <= wr_byte_cnt + 1'b1;
            
            if (wr_byte_cnt == 3'd7) begin
                wr_byte_cnt <= 3'd0;
                wr_keep_reg <= 8'hFF;  // 完整的64位数据
            end
        end
        
        // 检测最后一个不完整的数据
        if (!gmii_rx_dv && wr_dv_d0) begin
            wr_last_data <= 1'b1;
            wr_keep_reg  <= (8'hFF >> (7 - wr_byte_cnt));  // 设置有效字节标志
        end else if (wr_byte_cnt == 3'd7) begin
            wr_last_data <= 1'b0;
        end
    end
end

// 读时钟域控制
always @(posedge tx_clk_out or negedge rst_n) begin
    if (!rst_n) begin
        fifo_rd_en <= 1'b0;
        rd_valid   <= 1'b0;
        rd_last    <= 1'b0;
        rd_keep    <= 8'h00;
    end else begin
        if (!fifo_empty && axis_tready) begin  // FIFO有数据且AXI准备好
        // if (!fifo_empty )   begin          //调试用。
            fifo_rd_en <= 1'b1;
            rd_valid   <= 1'b1;
            if (wr_last_data) begin  // 处理最后一包数据
                rd_last <= 1'b1;
                rd_keep <= wr_keep_reg;  // 使用字节有效标志
            end else begin
                rd_last <= 1'b0;
                rd_keep <= 8'hFF;  // 完整64位数据
            end
        end else begin
            fifo_rd_en <= 1'b0;
            rd_valid   <= 1'b0;
        end
    end
end

// AXI Stream输出控制
always @(posedge tx_clk_out or negedge rst_n) begin
    if (!rst_n) begin
        axis_tvalid <= 1'b0;
        axis_tdata  <= 64'd0;
        axis_tlast  <= 1'b0;
        axis_tkeep  <= 8'h00;
    end else begin
        if (rd_valid) begin
            axis_tvalid <= 1'b1;
            axis_tdata  <= fifo_dout;
            axis_tlast  <= rd_last;
            axis_tkeep  <= rd_keep;
        end else begin
            axis_tvalid <= 1'b0;
            axis_tdata  <= 64'd0;
            axis_tlast  <= 1'b0;
            axis_tkeep  <= 8'h00;
        end
    end
end

endmodule