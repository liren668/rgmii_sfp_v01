//----------------------------------------------------------------------------------------
// File name:           axi_to_gmii
// Created by:          ɺ����˹��
// Created date:        2025.3
// Version:             V0.1
// Descriptions:        axi to gmii��������洢���ṹ��ȷ��gmii_txd���������
//
//----------------------------------------------------------------------------------------

module axi_to_gmii(
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

// ��ģ�鶥�������������
reg [2:0] clear_valid_req;     // ��ʱ�����������valid
(* ASYNC_REG = "TRUE" *) reg [2:0] sync_clear_req_1, sync_clear_req_2;  // дʱ����ͬ��

// ==================== дʱ����(156.25MHz) ====================
reg [63:0] buffer [0:2];        // ������洢��
reg [7:0]  keep_buffer [0:2];   // ����tkeep��Ϣ
reg        last_buffer [0:2];   // ����tlast��Ϣ
reg        data_valid [0:2];    // ������������Ч��־
reg [1:0]  wr_buf_sel;          // д����ѡ��

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
        sync_clear_req_1 <= 3'b0;
        sync_clear_req_2 <= 3'b0;
    end else begin
        // ͬ��clear_valid_req�ź�
        sync_clear_req_1 <= clear_valid_req;
        sync_clear_req_2 <= sync_clear_req_1;
        
        // �����������
        if (sync_clear_req_2[0]) data_valid[0] <= 1'b0;
        if (sync_clear_req_2[1]) data_valid[1] <= 1'b0;
        if (sync_clear_req_2[2]) data_valid[2] <= 1'b0;

        if (axis_tvalid) begin
            // ����д�뵱ǰ������
            last_buffer[wr_buf_sel] <= axis_tlast;
            if (!axis_tlast) begin
                buffer[wr_buf_sel] <= axis_tdata;
                keep_buffer[wr_buf_sel] <= axis_tkeep;
                data_valid[wr_buf_sel] <= 1'b1;
                 // �л�������
                wr_buf_sel <= (wr_buf_sel == 2'd2) ? 2'd0 : wr_buf_sel + 1'b1;
            end
        end
    end
end

// ==================== ��ʱ����(125MHz) ====================
reg [2:0]  rd_cnt;             // �ֽڼ�����(0-7)
reg [1:0]  rd_buf_sel;         // ������ѡ��
reg [63:0] rd_data;            // �����ݼĴ���
reg [7:0]  rd_keep;            // ��keep�Ĵ���
reg        rd_last;            // ��last�Ĵ���
reg        rd_valid;           // ����Ч��־
reg        start_send;         // ��ʼ���ͱ�־
reg [1:0]  valid_data_count;   // ��Ч���ݼ�����
reg        packet_sending;     // ���ݰ������б�־

// ��Ч���ݼ���������
always @(posedge gmii_tx_clk or negedge rst_n) begin
    if (!rst_n) begin
        valid_data_count <= 2'd0;
    end else begin
        // ������Ч���ݼ���
        case ({data_valid[0], data_valid[1], data_valid[2]})
            3'b000: valid_data_count <= 2'd0;
            3'b001, 3'b010, 3'b100: valid_data_count <= 2'd1;
            3'b011, 3'b101, 3'b110: valid_data_count <= 2'd2;
            3'b111: valid_data_count <= 2'd3;
        endcase
    end
end

// �������߼�
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
        // Ĭ����������ź�
        clear_valid_req <= 3'b0;

        // ���ݰ����������߼�
        if (!packet_sending && valid_data_count >= 2'd2) begin
            packet_sending <= 1'b1;
            rd_data <= buffer[rd_buf_sel];
            rd_keep <= keep_buffer[rd_buf_sel];
            rd_last <= last_buffer[rd_buf_sel];
            clear_valid_req[rd_buf_sel] <= 1'b1;  // �������valid
            rd_cnt <= 3'd0;
            rd_buf_sel <= (rd_buf_sel == 2'd2) ? 2'd0 : rd_buf_sel + 1'b1;
        end

        // ���ݷ����߼�
        if (packet_sending) begin
            // �������������rd_keep�ж��Ƿ������Ч����
            case (rd_cnt)
                3'd0: begin
                    if (rd_keep[0])  begin                  // ����rd_keepΪ1ʱ���������
                        gmii_tx_en <= 1'b1;
                        gmii_txd <= rd_data[7:0];
                    end else begin
                        gmii_tx_en <= 1'b0;
                        gmii_txd <= 8'h00;
                    end    
                end
                3'd1: begin
                    if (rd_keep[1])  begin                  // ����rd_keepΪ1ʱ���������
                        gmii_tx_en <= 1'b1;
                        gmii_txd <= rd_data[15:8];
                    end else begin
                        gmii_tx_en <= 1'b0;
                        gmii_txd <= 8'h00;
                    end    
                end
                3'd2: begin
                    if (rd_keep[2])  begin                  // ����rd_keepΪ1ʱ���������
                        gmii_tx_en <= 1'b1;
                        gmii_txd <= rd_data[23:16];
                    end else begin
                        gmii_tx_en <= 1'b0;
                        gmii_txd <= 8'h00;
                    end    
                end
                3'd3: begin
                    if (rd_keep[3])  begin                  // ����rd_keepΪ1ʱ���������
                        gmii_tx_en <= 1'b1;
                        gmii_txd <= rd_data[31:24];
                    end else begin
                        gmii_tx_en <= 1'b0;
                        gmii_txd <= 8'h00;
                    end    
                end
                3'd4: begin
                    if (rd_keep[4])  begin                  // ����rd_keepΪ1ʱ���������
                        gmii_tx_en <= 1'b1;
                        gmii_txd <= rd_data[39:32];
                    end else begin
                        gmii_tx_en <= 1'b0;
                        gmii_txd <= 8'h00;
                    end    
                end
                3'd5: begin
                    if (rd_keep[5])  begin                  // ����rd_keepΪ1ʱ���������
                        gmii_tx_en <= 1'b1;
                        gmii_txd <= rd_data[47:40];
                    end else begin
                        gmii_tx_en <= 1'b0;
                        gmii_txd <= 8'h00;
                    end    
                end
                3'd6: begin
                    if (rd_keep[6])  begin                  // ����rd_keepΪ1ʱ���������
                        gmii_tx_en <= 1'b1;
                        gmii_txd <= rd_data[55:48];
                    end else begin
                        gmii_tx_en <= 1'b0;
                        gmii_txd <= 8'h00;
                    end    
                end
                3'd7: begin
                    if (rd_keep[7]) begin
                        gmii_tx_en <= 1'b1;
                        gmii_txd <= rd_data[63:56];
                    end else begin
                        gmii_tx_en <= 1'b0;
                        gmii_txd <= 8'h00;
                    end

                    // ������ݰ���������
                    if (valid_data_count == 2'd0) begin
                        // ���ݰ���������
                        if (rd_last) begin
                            // ��ǰ���������һ����������ͽ���
                            packet_sending <= 1'b0;
                        end else begin
                            // ��һ��ʱ�����ڽ�������
                            rd_keep <= 8'h0;  // ���keep�źţ�ǿ����һ����tx_enΪ0
                            packet_sending <= 1'b0;
                        end
                    end else begin
                        // ����������Ҫ����
                        rd_data <= buffer[rd_buf_sel];
                        rd_keep <= keep_buffer[rd_buf_sel];
                        rd_last <= last_buffer[rd_buf_sel];
                        clear_valid_req[rd_buf_sel] <= 1'b1;
                        rd_buf_sel <= (rd_buf_sel == 2'd2) ? 2'd0 : rd_buf_sel + 1'b1;
                    end
                end
            endcase

            // ����������
            if (rd_cnt == 3'd7) begin
                rd_cnt <= 3'd0;
            end else begin
                rd_cnt <= rd_cnt + 1'b1;
            end
        end else begin
            gmii_tx_en <= 1'b0;
            gmii_txd <= 8'd0;
        end
    end
end

endmodule