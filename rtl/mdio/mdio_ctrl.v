//****************************************Copyright (c)***********************************//
//ԭ�Ӹ����߽�ѧƽ̨��www.yuanzige.com
//����֧�֣�www.openedv.com
//�Ա����̣�http://openedv.taobao.com 
//��ע΢�Ź���ƽ̨΢�źţ�"����ԭ��"����ѻ�ȡZYNQ & FPGA & STM32 & LINUX���ϡ�
//��Ȩ���У�����ؾ���
//Copyright(C) ����ԭ�� 2018-2028
//All rights reserved                                  
//----------------------------------------------------------------------------------------
// File name:           mdio_ctrl
// Last modified Date:  2020/2/6 17:25:36
// Last Version:        V1.0
// Descriptions:        MDIO�ӿڶ�д����
//----------------------------------------------------------------------------------------
// Created by:          ����ԭ��
// Created date:        2020/2/6 17:25:36
// Version:             V1.0
// Descriptions:        The original version
//
//----------------------------------------------------------------------------------------
//****************************************************************************************//
module mdio_ctrl(
    input                clk           ,
    input                rst_n         ,
    input                soft_rst_trig , //��λ�����ź�
    input                op_done       , //��д���
    input        [15:0]  op_rd_data    , //����������
    input                op_rd_ack     , //��Ӧ���ź� 0:Ӧ�� 1:δӦ��
    output  reg          op_exec       , //������ʼ�ź�
    output  reg          op_rh_wl      , //�͵�ƽд���ߵ�ƽ��
    output  reg  [4:0]   op_addr       , //�Ĵ�����ַ
    output  reg  [15:0]  op_wr_data    , //д��Ĵ���������
    output       [1:0]   led             //LED��ָʾ��̫������״̬
    );

parameter TIME_CNT = 24'd1_000_000;

//reg define
reg          rst_trig_d0;    
reg          rst_trig_d1;  
reg			 rst_trig_d2; 
reg          rst_trig_flag;   //soft_rst_trig�źŴ�����־
reg  [23:0]  timer_cnt;       //��ʱ������ 
reg          timer_done;      //��ʱ����ź�
reg          start_next;      //��ʼ����һ���Ĵ�������
reg          read_next;       //���ڶ���һ���Ĵ����Ĺ���
reg          link_error;      //��·�Ͽ�������Э��δ���
reg  [2:0]   flow_cnt;        //���̿��Ƽ����� 
reg  [1:0]   speed_status;    //�������� 

//wire define
wire         pos_rst_trig;    //soft_rst_trig�ź�������

//��soft_rst_trig�ź�������
assign pos_rst_trig = ~rst_trig_d2 & rst_trig_d1;
//δ���ӻ�����ʧ��ʱled��ֵ00
// 01:10Mbps  10:100Mbps  11:1000Mbps 00���������
assign led = link_error ? 2'b00: speed_status;
//��soft_rst_trig�ź���ʱ����
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        rst_trig_d0 <= 1'b0;
        rst_trig_d1 <= 1'b0;
		rst_trig_d2 <= 1'b0;
    end
    else begin
        rst_trig_d0 <= soft_rst_trig;
        rst_trig_d1 <= rst_trig_d0;
		rst_trig_d2 <= rst_trig_d1;
    end
end

//��ʱ����
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        timer_cnt <= 1'b0;
        timer_done <= 1'b0;
    end
    else begin
        if(timer_cnt == TIME_CNT - 1'b1) begin
            timer_done <= 1'b1;
            timer_cnt <= 1'b0;
        end
        else begin
            timer_done <= 1'b0;
            timer_cnt <= timer_cnt + 1'b1;
        end
    end
end    

//������λ�źŶ�MDIO�ӿڽ�����λ,����ʱ��ȡ��̫��������״̬
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        flow_cnt <= 3'd0;
        rst_trig_flag <= 1'b0;
        speed_status <= 2'b00;
        op_exec <= 1'b0; 
        op_rh_wl <= 1'b0; 
        op_addr <= 5'h0; 
        op_wr_data <= 16'h0; 
        start_next <= 1'b0; 
        read_next <= 1'b0; 
        link_error <= 1'b0;
    end
    else begin
        op_exec <= 1'b0; 
        if(pos_rst_trig)                      
            rst_trig_flag <= 1'b1;             //������λ������־
        case(flow_cnt)
            2'd0 : begin
                if(rst_trig_flag) begin        //��ʼ��MDIO�ӿڽ�����λ
                    op_exec <= 1'b1; 
                    op_rh_wl <= 1'b0; 
					op_addr <= 5'h0;
                    op_wr_data <= 16'h9140;    //Bit[15]=1'b1,��ʾ��λ
                    flow_cnt <= 3'd1;
                end
                else if(timer_done) begin      //��ʱ���,��ȡ��̫������״̬
                    op_exec <= 1'b1; 
                    op_rh_wl <= 1'b1;
					//op_addr <= 5'h05; 		   //���ڷ���
					op_addr <= 5'h01; 		//��ַ
                    flow_cnt <= 3'd2;
                end
                else if(start_next) begin      //��ʼ����һ���Ĵ�������ȡ��̫��ͨ���ٶ�
                    op_exec <= 1'b1; 
                    op_rh_wl <= 1'b1; 
					op_addr <= 5'h11;		   //�Ĵ�����ַ
					//op_addr <= 5'h06;		   //���ڷ���
                    flow_cnt <= 3'd2;
                    start_next <= 1'b0; 
                    read_next <= 1'b1; 
                end
            end    
            2'd1 : begin
                if(op_done) begin              //MDIO�ӿ���λ���
                    flow_cnt <= 3'd0;
                    rst_trig_flag <= 1'b0;
                end
            end
            2'd2 : begin                       
                if(op_done) begin              //MDIO�ӿڶ��������
                    if(op_rd_ack == 1'b0 && read_next == 1'b0) //����һ���Ĵ������ӿڳɹ�Ӧ��
                        flow_cnt <= 3'd3;                      //������һ���Ĵ������ӿڳɹ�Ӧ��
                    else if(op_rd_ack == 1'b0 && read_next == 1'b1)begin 
                        read_next <= 1'b0;
                        flow_cnt <= 3'd4;
                    end
                    else begin
                        flow_cnt <= 3'd0;
                     end
                end    
            end
            2'd3 : begin                     
                flow_cnt <= 3'd0;          //��·����������Э�����
                if(op_rd_data[5] == 1'b1 && op_rd_data[2] == 1'b1)begin
                    start_next <= 1;
                    link_error <= 0;
                end
                else begin
                    link_error <= 1'b1;  
               end           
            end
            3'd4: begin
                flow_cnt <= 3'd0;
                if(op_rd_data[15:14] == 2'b10)
                    speed_status <= 2'b11; //1000Mbps
                else if(op_rd_data[15:14] == 2'b01) 
                    speed_status <= 2'b10; //100Mbps 
                else if(op_rd_data[15:14] == 2'b00) 
                    speed_status <= 2'b01; //10Mbps
                else
                    speed_status <= 2'b00; //�������  
            end
        endcase
    end    
end    

endmodule