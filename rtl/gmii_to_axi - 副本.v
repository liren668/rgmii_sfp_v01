//----------------------------------------------------------------------------------------
// File name:           gmii_to_axi
// Created by:          ɺ����˹��
// Created date:        2025.3
// Version:             V0.1
// Descriptions:        gmii_to_axi
//
//----------------------------------------------------------------------------------------

module gmii_to_axi(
    input                gmii_rx_clk  ,  // RGMII����ʱ��
    input                tx_clk_out   ,  // ����ʱ��
    input                rst_n        ,  // ��λ�źţ��͵�ƽ��Ч
    input                gmii_rx_dv   ,  // GMII����������Ч�ź�
    input        [7:0]   gmii_rxd     ,  // GMII��������
    output  reg          axis_tvalid  ,  // AXI������Ч�ź�
    output  reg  [63:0]  axis_tdata   ,  // AXI����
    output  reg          axis_tlast   ,  // AXI���һ�����ݱ�־
    output  reg  [7:0]   axis_tkeep   ,  // AXI������Ч�ֽڱ�־
    input                axis_tready     // AXI׼���ý����ź�
);

// дʱ����Ĵ���
reg  [2:0]   wr_byte_cnt;   // дʱ�����ֽڼ�����
reg          wr_dv_d0;      // дʱ����dv�ӳ�
reg          wr_last_data;  // дʱ����������ݱ�־
reg  [7:0]   wr_keep_reg;   // дʱ������Ч�ֽڱ�־

// ��ʱ����Ĵ���
reg          rd_valid;      // ��ʱ������Ч�ź�
reg          rd_last;       // ��ʱ����������ݱ�־
reg  [7:0]   rd_keep;       // ��ʱ������Ч�ֽڱ�־

// FIFO�����ź�
wire         fifo_wr_en;
// wire [7:0]   fifo_din;      // 8λ����
wire [63:0]  fifo_dout;     // 64λ���
wire         fifo_empty;     // FIFO���ź�
reg          fifo_rd_en;    // FIFO��ʹ��

// FIFOд����
assign fifo_wr_en = gmii_rx_dv;  // ���ڶ�ʱ�ӿ���дʱ�ӣ�������FIFO��״̬
assign fifo_din = gmii_rxd;

// FIFOʵ������FIFO_DEPTH = 256��
async_fifo_8to64 u_rx_async_fifo (
    .rst           (~rst_n),             //  ��λ�ź�
    .wr_clk        (gmii_rx_clk),         // дʱ���ź�
    .wr_en         (fifo_wr_en),          // дʹ���ź�
    .din           (fifo_din),            // д��8λ����
    .rd_clk        (tx_clk_out),          // ��ʱ���ź�
    .rd_en         (fifo_rd_en),          // ��ʹ���ź�
    .dout          (fifo_dout),           // ����64λ����
    .empty         (fifo_empty)           // FIFO���ź�
);

// дʱ�������ݴ���
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
                wr_keep_reg <= 8'hFF;  // ������64λ����
            end
        end
        
        // ������һ��������������
        if (!gmii_rx_dv && wr_dv_d0) begin
            wr_last_data <= 1'b1;
            wr_keep_reg  <= (8'hFF >> (7 - wr_byte_cnt));  // ������Ч�ֽڱ�־
        end else if (wr_byte_cnt == 3'd7) begin
            wr_last_data <= 1'b0;
        end
    end
end

// ��ʱ�������
always @(posedge tx_clk_out or negedge rst_n) begin
    if (!rst_n) begin
        fifo_rd_en <= 1'b0;
        rd_valid   <= 1'b0;
        rd_last    <= 1'b0;
        rd_keep    <= 8'h00;
    end else begin
        if (!fifo_empty && axis_tready) begin  // FIFO��������AXI׼����
        // if (!fifo_empty )   begin          //�����á�
            fifo_rd_en <= 1'b1;
            rd_valid   <= 1'b1;
            if (wr_last_data) begin  // �������һ������
                rd_last <= 1'b1;
                rd_keep <= wr_keep_reg;  // ʹ���ֽ���Ч��־
            end else begin
                rd_last <= 1'b0;
                rd_keep <= 8'hFF;  // ����64λ����
            end
        end else begin
            fifo_rd_en <= 1'b0;
            rd_valid   <= 1'b0;
        end
    end
end

// AXI Stream�������
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