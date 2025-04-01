//****************************************Copyright (c)***********************************//
//ԭ�Ӹ����߽�ѧƽ̨��www.yuanzige.com
//����֧�֣�www.openedv.com
//�Ա����̣�http://openedv.taobao.com 
//��ע΢�Ź���ƽ̨΢�źţ�"����ԭ��"����ѻ�ȡZYNQ & FPGA & STM32 & LINUX���ϡ�
//��Ȩ���У�����ؾ���
//Copyright(C) ����ԭ�� 2018-2028
//All rights reserved                                  
//----------------------------------------------------------------------------------------
// File name:           mdio_dri
// Last modified Date:  2020/2/6 17:25:36
// Last Version:        V1.0
// Descriptions:        MDIO�ӿ�����
//----------------------------------------------------------------------------------------
// Created by:          ����ԭ��
// Created date:        2020/2/6 17:25:36
// Version:             V1.0
// Descriptions:        The original version
//
//----------------------------------------------------------------------------------------
//****************************************************************************************//

module mdio_dri #(
    parameter  PHY_ADDR = 5'b00100,//PHY��ַ
    parameter  CLK_DIV  = 6'd16    //��Ƶϵ��
   )
    (
    input                clk       , //ʱ���ź�
    input                rst_n     , //��λ�ź�,�͵�ƽ��Ч
    input                op_exec   , //������ʼ�ź�
    input                op_rh_wl  , //�͵�ƽд���ߵ�ƽ��
    input        [4:0]   op_addr   , //�Ĵ�����ַ
    input        [15:0]  op_wr_data, //д��Ĵ���������
    output  reg          op_done   , //��д���
    output  reg  [15:0]  op_rd_data, //����������
    output  reg          op_rd_ack , //��Ӧ���ź� 0:Ӧ�� 1:δӦ��
    output  reg          dri_clk   , //����ʱ��100M 8��Ƶ��12.5MHZ
    
    output  reg          eth_mdc   , //PHY����ӿڵ�ʱ���ź�
    inout                eth_mdio    //PHY����ӿڵ�˫�������ź�
    );

//parameter define
localparam st_idle    = 6'b00_0001;  //����״̬
localparam st_pre     = 6'b00_0010;  //����PRE(ǰ����)
localparam st_start   = 6'b00_0100;  //��ʼ״̬,����ST(��ʼ)+OP(������)
localparam st_addr    = 6'b00_1000;  //д��ַ,����PHY��ַ+�Ĵ�����ַ
localparam st_wr_data = 6'b01_0000;  //TA+д����
localparam st_rd_data = 6'b10_0000;  //TA+������

//reg define
reg    [5:0]  cur_state ;
reg    [5:0]  next_state;

reg    [5:0]  clk_cnt   ;  //��Ƶ����                      
reg   [15:0]  wr_data_t ;  //����д�Ĵ���������
reg    [4:0]  addr_t    ;  //����Ĵ�����ַ
reg    [6:0]  cnt       ;  //������
reg           st_done   ;  //״̬��ʼ��ת�ź�
reg    [1:0]  op_code   ;  //������  2'b01(д)  2'b10(��)                  
reg           mdio_dir  ;  //MDIO����(SDA)�������
reg           mdio_out  ;  //MDIO����ź�
reg   [15:0]  rd_data_t ;  //������Ĵ�������

//wire define
wire          mdio_in    ; //MDIO��������
wire   [5:0]  clk_divide ; //PHY_CLK�ķ�Ƶϵ��

assign eth_mdio = mdio_dir ? mdio_out : 1'bz; //����˫��io����
assign mdio_in = eth_mdio;                    //MDIO��������
//��PHY_CLK�ķ�Ƶϵ������2,�õ�dri_clk�ķ�Ƶϵ��,�����MDC��MDIO�źŲ���
assign clk_divide = CLK_DIV >> 1;

//��Ƶ�õ�dri_clkʱ��
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        dri_clk <=  1'b0;
        clk_cnt <= 1'b0;
    end
    else if(clk_cnt == clk_divide[5:1] - 1'd1) begin
        clk_cnt <= 1'b0;
        dri_clk <= ~dri_clk;
    end
    else
        clk_cnt <= clk_cnt + 1'b1;
end

//����PHY_MDCʱ��
always @(posedge dri_clk or negedge rst_n) begin
    if(!rst_n)
        eth_mdc <= 1'b1;
    else if(cnt[0] == 1'b0)
        eth_mdc <= 1'b1;
    else    
        eth_mdc <= 1'b0;  
end

//(����ʽ״̬��)ͬ��ʱ������״̬ת��
always @(posedge dri_clk or negedge rst_n) begin
    if(!rst_n)
        cur_state <= st_idle;
    else
        cur_state <= next_state;
end  

//����߼��ж�״̬ת������
always @(*) begin
    next_state = st_idle;
    case(cur_state)
        st_idle : begin
            if(op_exec)
                next_state = st_pre;
            else 
                next_state = st_idle;   
        end  
        st_pre : begin
            if(st_done)
                next_state = st_start;
            else
                next_state = st_pre;
        end
        st_start : begin
            if(st_done)
                next_state = st_addr;
            else
                next_state = st_start;
        end
        st_addr : begin
            if(st_done) begin
                if(op_code == 2'b01)                //MDIO�ӿ�д����  
                    next_state = st_wr_data;
                else
                    next_state = st_rd_data;        //MDIO�ӿڶ�����  
            end
            else
                next_state = st_addr;
        end
        st_wr_data : begin
            if(st_done)
                next_state = st_idle;
            else
                next_state = st_wr_data;
        end        
        st_rd_data : begin
            if(st_done)
                next_state = st_idle;
            else
                next_state = st_rd_data;
        end                                                                          
        default : next_state = st_idle;
    endcase
  end

//ʱ���·����״̬���
always @(posedge dri_clk or negedge rst_n) begin
    if(!rst_n) begin
        cnt <= 5'd0;
        op_code <= 2'd0;
        addr_t <= 5'd0;
        wr_data_t <= 16'd0;
        rd_data_t <= 16'd0;
        op_done <= 1'b0;
        st_done <= 1'b0; 
        op_rd_data <= 16'd0;
        op_rd_ack <= 1'b1;
        mdio_dir <= 1'b0;
        mdio_out <= 1'b1;
    end
    else begin
        st_done <= 1'b0 ;                            
        cnt     <= cnt +1'b1 ;          
        case(cur_state)
            st_idle : begin
                mdio_out <= 1'b1;                     
                mdio_dir <= 1'b0;                     
                op_done <= 1'b0;                     
                cnt <= 7'b0;  
                if(op_exec) begin
                    op_code <= {op_rh_wl,~op_rh_wl}; //OP_CODE: 2'b01(д)  2'b10(��) 
                    addr_t <= op_addr;
                    wr_data_t <= op_wr_data;
                    op_rd_ack <= 1'b1;
                end     
            end 
            st_pre : begin                          //����ǰ����:32��1bit 
                mdio_dir <= 1'b1;                   //�л�MDIO���ŷ���:���
                mdio_out <= 1'b1;                   //MDIO��������ߵ�ƽ
                if(cnt == 7'd62) 
                    st_done <= 1'b1;
                else if(cnt == 7'd63)
                    cnt <= 7'b0;
            end            
            st_start  : begin
                case(cnt)
                    7'd1 : mdio_out <= 1'b0;        //���Ϳ�ʼ�ź� 2'b01
                    7'd3 : mdio_out <= 1'b1; 
                    7'd5 : mdio_out <= op_code[1];  //���Ͳ�����
                    7'd6 : st_done <= 1'b1;
                    7'd7 : begin
                               mdio_out <= op_code[0];
                               cnt <= 7'b0;  
                           end    
                    default : ;
                endcase
            end    
            st_addr : begin
                case(cnt)
                    7'd1 : mdio_out <= PHY_ADDR[4]; //����PHY��ַ
                    7'd3 : mdio_out <= PHY_ADDR[3];
                    7'd5 : mdio_out <= PHY_ADDR[2];
                    7'd7 : mdio_out <= PHY_ADDR[1];  
                    7'd9 : mdio_out <= PHY_ADDR[0];
                    7'd11: mdio_out <= addr_t[4];  //���ͼĴ�����ַ
                    7'd13: mdio_out <= addr_t[3];
                    7'd15: mdio_out <= addr_t[2];
                    7'd17: mdio_out <= addr_t[1];  
                    7'd18: st_done <= 1'b1;
                    7'd19: begin
                               mdio_out <= addr_t[0]; 
                               cnt <= 7'd0;
                           end    
                    default : ;
                endcase                
            end    
            st_wr_data : begin
                case(cnt)
                    7'd1 : mdio_out <= 1'b1;         //����TA,д����(2'b10)
                    7'd3 : mdio_out <= 1'b0;
                    7'd5 : mdio_out <= wr_data_t[15];//����д�Ĵ�������
                    7'd7 : mdio_out <= wr_data_t[14];
                    7'd9 : mdio_out <= wr_data_t[13];
                    7'd11: mdio_out <= wr_data_t[12];
                    7'd13: mdio_out <= wr_data_t[11];
                    7'd15: mdio_out <= wr_data_t[10];
                    7'd17: mdio_out <= wr_data_t[9];
                    7'd19: mdio_out <= wr_data_t[8];
                    7'd21: mdio_out <= wr_data_t[7];
                    7'd23: mdio_out <= wr_data_t[6];
                    7'd25: mdio_out <= wr_data_t[5];
                    7'd27: mdio_out <= wr_data_t[4];
                    7'd29: mdio_out <= wr_data_t[3];
                    7'd31: mdio_out <= wr_data_t[2];
                    7'd33: mdio_out <= wr_data_t[1];
                    7'd35: mdio_out <= wr_data_t[0];
                    7'd37: begin
                        mdio_dir <= 1'b0;
                        mdio_out <= 1'b1;
                    end
                    7'd39: st_done <= 1'b1;           
                    7'd40: begin
                               cnt <= 7'b0;
                               op_done <= 1'b1;      //д�������,����op_done�ź� 
                           end    
                    default : ;
                endcase    
            end
            st_rd_data : begin
                case(cnt)
                    7'd1 : begin
                        mdio_dir <= 1'b0;            //MDIO�����л�������״̬
                        mdio_out <= 1'b1;
                    end
                    7'd2 : ;                         //TA[1]λ,��λΪ����״̬,������             
                    7'd4 : op_rd_ack <= mdio_in;     //TA[0]λ,0(Ӧ��) 1(δӦ��)
                    7'd6 : rd_data_t[15] <= mdio_in; //���ռĴ�������
                    7'd8 : rd_data_t[14] <= mdio_in;
                    7'd10: rd_data_t[13] <= mdio_in;
                    7'd12: rd_data_t[12] <= mdio_in;
                    7'd14: rd_data_t[11] <= mdio_in;
                    7'd16: rd_data_t[10] <= mdio_in;
                    7'd18: rd_data_t[9] <= mdio_in;
                    7'd20: rd_data_t[8] <= mdio_in;
                    7'd22: rd_data_t[7] <= mdio_in;
                    7'd24: rd_data_t[6] <= mdio_in;
                    7'd26: rd_data_t[5] <= mdio_in;
                    7'd28: rd_data_t[4] <= mdio_in;
                    7'd30: rd_data_t[3] <= mdio_in;
                    7'd32: rd_data_t[2] <= mdio_in;
                    7'd34: rd_data_t[1] <= mdio_in;
                    7'd36: rd_data_t[0] <= mdio_in;
                    7'd39: st_done <= 1'b1;
                    7'd40: begin
                        op_done <= 1'b1;             //���������,����op_done�ź�          
                        op_rd_data <= rd_data_t;
                        rd_data_t <= 16'd0;
                        cnt <= 7'd0;
                    end
                    default : ;
                endcase   
            end                
            default : ;
        endcase               
    end
end                    

endmodule