//----------------------------------------------------------------------------------------
// File name:           axi_to_gmii
// Created by:          ɺ����˹��
// Created date:        2025.3
// Version:             V0.1
// Descriptions:        axi to gmii��������洢���ṹ��ȷ��gmii_txd���������
//
//----------------------------------------------------------------------------------------

module axi_to_gmii(
    // input                dclk,           // ������ 100MHzʱ��
    input                rst_n,          // ��λ�źţ��͵�ƽ��Ч
    
    // AXI Stream �ӿ� (156.25MHz)
    input                tx_clk_out,     // AXIʱ����дʱ��
    input                axis_tvalid,    // AXI������Ч�ź�
    input        [63:0]  axis_tdata,     // AXI����
    input                axis_tlast,     // ��������־
    input        [7:0]   axis_tkeep,     // �ֽ���Ч����
    
    // GMII �ӿ� (125MHz)
    input                gmii_tx_clk,    // GMIIʱ�����ʱ��
    output reg           gmii_tx_en,     // GMII����������Ч
    output reg  [7:0]    gmii_txd        // GMII��������
);

// ==================== дʱ����(156.25MHz) ====================
reg [63:0] buffer [0:2];        // ������洢��
reg [7:0]  keep_buffer [0:2];   // ����tkeep��Ϣ
reg        last_buffer [0:2];   // ����tlast��Ϣ
reg        data_valid [0:2];    // ������������Ч��־
reg [1:0]  wr_buf_sel;          // д����ѡ��

// ��������ź�
reg [2:0] clear_valid_req;     // ��ʱ�����������valid
(* ASYNC_REG = "TRUE" *) reg [2:0] clear_valid_req_sync1, clear_valid_req_sync2;  // ͬ����дʱ����

// д�����߼�
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
        // ͬ��clear_valid_req�ź�
        clear_valid_req_sync1 <= clear_valid_req;
        clear_valid_req_sync2 <= clear_valid_req_sync1;
        
        // ����ͬ������������valid��չ��forѭ����
        if(clear_valid_req_sync2[0]) data_valid[0] <= 1'b0;
        if(clear_valid_req_sync2[1]) data_valid[1] <= 1'b0;
        if(clear_valid_req_sync2[2]) data_valid[2] <= 1'b0;
        
        if (axis_tvalid) begin
            // ����д�뵱ǰ������
            buffer[wr_buf_sel] <= axis_tdata;
            keep_buffer[wr_buf_sel] <= axis_tkeep;
            last_buffer[wr_buf_sel] <= axis_tlast;
            data_valid[wr_buf_sel] <= 1'b1;  // д��������λvalid
            // �л�������
            wr_buf_sel <= (wr_buf_sel == 2'd2) ? 2'd0 : wr_buf_sel + 1'b1;
        end
    end
end

// ͬ���Ĵ���
(* ASYNC_REG = "TRUE" *) reg sync_data_valid_stage[2:0];
always @(posedge gmii_tx_clk or negedge rst_n) begin
    if (!rst_n) begin
        sync_data_valid_stage[0] <= 1'b0;
        sync_data_valid_stage[1] <= 1'b0;
        sync_data_valid_stage[2] <= 1'b0;
    end else begin
        // ��ÿһλ����˫�Ĵ���ͬ��
        sync_data_valid_stage[0] <= data_valid[0];
        sync_data_valid_stage[1] <= data_valid[1];
        sync_data_valid_stage[2] <= data_valid[2];
    end
end

// ��ͬ������ź���ϳ�һ���µ��ź�
wire [2:0] sync_data_valid = {sync_data_valid_stage[2], sync_data_valid_stage[1], sync_data_valid_stage[0]};

// ==================== ��ʱ����(125MHz) ====================
reg [2:0]  rd_cnt;             // �ֽڼ�����(0-7)
reg [1:0]  rd_buf_sel;         // ������ѡ��
reg [63:0] rd_data;            // �����ݼĴ���
reg [7:0]  rd_keep;            // ��keep�Ĵ���
reg        rd_last;            // ��last�Ĵ���
reg [1:0]  valid_data_count;   // ��Ч���ݼ�����
reg        packet_sending;     // ���ݰ������б�־

// ��Ч���ݼ���������
always @(posedge gmii_tx_clk or negedge rst_n) begin
    if (!rst_n) begin
        valid_data_count <= 2'd0;
    end else begin
        // ������Ч���ݼ���
        case (sync_data_valid)
            3'b000: valid_data_count <= 2'd0;
            3'b001, 3'b010, 3'b100: valid_data_count <= 2'd1;
            3'b011, 3'b101, 3'b110: valid_data_count <= 2'd2;
            3'b111: valid_data_count <= 2'd3;
        endcase
    end
end

// �޸Ķ������߼�����
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
        // ���ݰ����������߼�
        if (!packet_sending && valid_data_count >= 2'd2) begin
            packet_sending <= 1'b1;
            rd_data <= buffer[rd_buf_sel];
            rd_keep <= keep_buffer[rd_buf_sel];
            rd_last <= last_buffer[rd_buf_sel];
            clear_valid_req[rd_buf_sel] <= 1'b1;  // �������valid
            rd_cnt <= 3'd0;
            rd_buf_sel <= (rd_buf_sel == 2'd2) ? 2'd0 : rd_buf_sel + 1'b1;
        end else begin
            clear_valid_req <= 3'b0;  // �������
        end

        // ���ݷ����߼�
        if (packet_sending) begin
            // �������������rd_keep�ж��Ƿ������Ч����
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
                    
                    // ��ǰһ������׼����һ������
                    if (!rd_last && sync_data_valid[rd_buf_sel]) begin
                        rd_data <= buffer[rd_buf_sel];
                        rd_keep <= keep_buffer[rd_buf_sel];
                        rd_last <= last_buffer[rd_buf_sel];
                        clear_valid_req[rd_buf_sel] <= 1'b1;  // �������valid
                        rd_buf_sel <= (rd_buf_sel == 2'd2) ? 2'd0 : rd_buf_sel + 1'b1;
                    end
                end
            endcase

            // ����������
            if (rd_cnt == 3'd7) begin
                if (rd_last || !rd_keep[7]) begin
                    packet_sending <= 1'b0;
                end
                rd_cnt <= 3'd0;
            end else begin
                if (rd_last && !rd_keep[rd_cnt]) begin
                    // ��������һ�����ݰ��ҵ�ǰ�ֽ���Ч����������
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