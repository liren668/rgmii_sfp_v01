//----------------------------------------------------------------------------------------
// File name:           gmii_to_axi
// Created by:          ɺ����˹��
// Created date:        2025.3
// Version:             V0.1
// Descriptions:        gmii_to_axi
//˫����GMII��AXIת����������GMII����8bit��ת��ΪAXI64bit����ʽ
//----------------------------------------------------------------------------------------
module gmii_to_axi(
    input             clk_ila,       // ILAʱ��
    input             gmii_rx_clk,    // 125MHzдʱ��
    input             tx_clk_out,     // 156.25MHz��ʱ��
    input             rst_n,
    input             gmii_rx_dv,     // GMII������Ч
    input  [7:0]      gmii_rxd,       // GMII��������
    output reg        axis_tvalid,    // AXI��Ч�ź�
    output reg [63:0] axis_tdata,
    output reg        axis_tlast,     // ��������־
    output reg [7:0]  axis_tkeep,     // �ֽ���Ч����
    input             axis_tready     // ���ξ����ź�
);

// ==================== дʱ�����߼���125MHz��====================
reg [63:0] buffer [0:1];        // ˫����洢��
reg        wr_buf_sel;          // д����ѡ��0/1��
reg [2:0]  wr_cnt;              // �ֽڼ�������0-7��
reg [2:0]  valid_bytes [0:1];   // ��������Ч�ֽ���
reg        pkt_end [0:1];       // ��������־

//ILAʵ����
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

(* ASYNC_REG = "TRUE" *) reg [1:0] sync_rd_buf_sel; // ��ָ��ͬ����

// д�����߼�
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
            // �������
            buffer[wr_buf_sel][wr_cnt*8 +:8] <= gmii_rxd;    //��һ���ֽ� (wr_cnt=0): ��䵽 [7:0]
                                                             //�ڶ����ֽ� (wr_cnt=1): ��䵽 [15:8]
                                                             //�������ֽ� (wr_cnt=2): ��䵽 [23:16] ...�Դ�����                      
            if (wr_cnt == 3'd7) begin // ������д��
                valid_bytes[wr_buf_sel] <= 3'd0;  // �޸����0��ʾ8���ֽڶ���Ч
                pkt_end[wr_buf_sel] <= 1'b0;
                wr_cnt <= 0;
                // �������л�����������ֹ���ݶ�ʧ
                wr_buf_sel <= ~wr_buf_sel;
            end else begin
                wr_cnt <= wr_cnt + 1;
            end
        end 
        else if (wr_cnt != 0) begin // ����������
            valid_bytes[wr_buf_sel] <=  wr_cnt ;
            pkt_end[wr_buf_sel] <= 1'b1;
            wr_cnt <= 0;
            // �������л�����������ֹ���ݶ�ʧ
            wr_buf_sel <= ~wr_buf_sel;
        end
    end
end

// ==================== ��ʱ�����߼���156.25MHz��====================
reg        rd_buf_sel;          // ������ѡ��0/1��
(* ASYNC_REG = "TRUE" *) reg [1:0] sync_wr_buf_sel; // дָ��ͬ����

always @(posedge tx_clk_out or negedge rst_n) begin
    if (!rst_n) begin
        rd_buf_sel <= 0;
        axis_tvalid <= 1'b0;
        axis_tdata <= 64'd0;
        axis_tlast <= 1'b0;
        axis_tkeep <= 8'h00;
    end else begin
        if (sync_wr_buf_sel[1] != sync_rd_buf_sel[1]) begin
            axis_tvalid <= 1'b1;  // �����ø�validֱ�����ֳɹ�
            axis_tdata <= buffer[rd_buf_sel];
            axis_tlast <= pkt_end[rd_buf_sel];
            axis_tkeep <= calc_tkeep(valid_bytes[rd_buf_sel]);
            
            if (axis_tready) begin
                rd_buf_sel <= ~rd_buf_sel; // �������ֳɹ�ʱ�л�������
            end
        end else begin
            axis_tvalid <= 1'b0;
        end
    end
end

// tkeep���ɺ���
function [7:0] calc_tkeep(input [2:0] bytes);
    case(bytes)
        3'd0: calc_tkeep = 8'hFF;    // 8����Ч�ֽ�
        3'd1: calc_tkeep = 8'h01;    // 1����Ч�ֽ�
        3'd2: calc_tkeep = 8'h03;    // 2����Ч�ֽ�
        3'd3: calc_tkeep = 8'h07;    // 3����Ч�ֽ�
        3'd4: calc_tkeep = 8'h0F;    // 4����Ч�ֽ�
        3'd5: calc_tkeep = 8'h1F;    // 5����Ч�ֽ�
        3'd6: calc_tkeep = 8'h3F;    // 6����Ч�ֽ�
        3'd7: calc_tkeep = 8'h7F;    // 7����Ч�ֽ�
        default: calc_tkeep = 8'hFF;  // ��ֹ�쳣���
    endcase
endfunction

// ==================== ��ʱ����ͬ�� ====================
// дָ��ͬ������ʱ����
always @(posedge tx_clk_out) begin
    sync_wr_buf_sel[0] <= wr_buf_sel;
    sync_wr_buf_sel[1] <= sync_wr_buf_sel[0];
end

// ��ָ��ͬ����дʱ����
always @(posedge gmii_rx_clk) begin
    sync_rd_buf_sel[0] <= rd_buf_sel;
    sync_rd_buf_sel[1] <= sync_rd_buf_sel[0];
end

endmodule