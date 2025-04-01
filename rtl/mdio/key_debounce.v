//****************************************Copyright (c)***********************************//
//ԭ�Ӹ����߽�ѧƽ̨��www.yuanzige.com
//����֧�֣�http://www.openedv.com/forum.php
//�Ա����̣�https://zhengdianyuanzi.tmall.com
//��ע΢�Ź���ƽ̨΢�źţ�"����ԭ��"����ѻ�ȡZYNQ & FPGA & STM32 & LINUX���ϡ�
//��Ȩ���У�����ؾ���
//Copyright(C) ����ԭ�� 2023-2033
//All rights reserved                                  
//----------------------------------------------------------------------------------------
// File name:           key_debounce
// Created by:          ����ԭ��
// Created date:        2023��2��16��14:20:02
// Version:             V1.0
// Descriptions:        ��������ģ��
//
//----------------------------------------------------------------------------------------
//****************************************************************************************//

module key_debounce(
    input        sys_clk   ,
    input        sys_rst_n ,

    input        key       ,   //�ⲿ����İ���ֵ
    output  reg  key_filter    //�����������ֵ
);

//parameter define
parameter  CNT_MAX = 20'd100_0000;    //����ʱ��20ms

//reg define
reg [19:0] cnt ;
reg        key_d0;            //�������ź��ӳ�һ��ʱ������
reg        key_d1;            //�������ź��ӳ�����ʱ������

//*****************************************************
//**                    main code
//*****************************************************

//�԰����˿ڵ������ӳ�����ʱ������
always @ (posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n) begin
        key_d0 <= 1'b1;
        key_d1 <= 1'b1;
    end
    else begin
        key_d0 <= key;
        key_d1 <= key_d0;
    end 
end

//����ֵ����
always @ (posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n) 
        cnt <= 20'd0;
    else begin
        if(key_d1 != key_d0)    //��⵽����״̬�����仯
            cnt <= CNT_MAX;     //�򽫼�������Ϊ20'd100_0000��
                                //����ʱ100_0000 * 20ns(1s/50MHz) = 20ms
        else begin              //�����ǰ����ֵ��ǰһ������ֵһ����������û�з����仯
            if(cnt > 20'd0)     //��������ݼ���0
                cnt <= cnt - 1'b1;  
            else
                cnt <= 20'd0;
        end
    end
end

//������������յİ���ֵ�ͳ�ȥ
always @ (posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n)
        key_filter <= 1'b1;
	//�ڼ������ݼ���1ʱ�ͳ�����ֵ
    else if(cnt == 20'd1) 
		key_filter <= key_d1;
    else
		key_filter <= key_filter;
end

endmodule

