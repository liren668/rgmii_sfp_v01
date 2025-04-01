//****************************************Copyright (c)***********************************//
//��Ȩ���У�����ؾ���
//Copyright(C) ɺ����˹�� 2025.3
//All rights reserved                                  
//----------------------------------------------------------------------------------------
// File name:           rgmii_rx
// Last modified Date:  
// Last Version:        
// Descriptions:        RGMII����ģ��
//----------------------------------------------------------------------------------------
// Created by:          ɺ����˹��
// Created date:        2025.3.5
// Version:             V0.1
// Descriptions:        The original version
//
//----------------------------------------------------------------------------------------
//****************************************************************************************//

module rgmii_rx(
    //��̫��RGMII�ӿ�
    input              rgmii_rxc   ,    //RGMII����ʱ��
    input              rgmii_rx_ctl,    //RGMII�������ݿ����ź�
    input       [3:0]  rgmii_rxd   ,    //RGMII��������    

    //��̫��GMII�ӿ�
    output             gmii_rx_clk ,    //GMII����ʱ��
    output             gmii_rx_dv  ,    //GMII����������Ч�ź�
    output      [7:0]  gmii_rxd        //GMII��������   
    // input              gmii_rx_er       //GMII�������ݴ����ź�
    );

//wire define
wire         rgmii_rxc_bufg;             //ȫ��ʱ�ӻ���
wire         rgmii_rxc_bufio;            //ȫ��ʱ��IO����
wire  [1:0]  gmii_rxdv_t;                //��λGMII������Ч�ź� 

//*****************************************************
//**                    main code
//*****************************************************

assign gmii_rx_clk = rgmii_rxc_bufg;
// ��gmii_rx_erΪ1ʱΪ10/100Mģʽ��ʹ�õ�һ������ֵ
// ��gmii_rx_erΪ0ʱΪ1000Mģʽ��ʹ����������ֵ������
assign gmii_rx_dv = gmii_rxdv_t[0] & gmii_rxdv_t[1];

//ȫ��ʱ�ӻ���
BUFG BUFG_inst (
    .I            (rgmii_rxc),      // 1-bit input: Clock input
    .O            (rgmii_rxc_bufg)  // 1-bit output: Clock output
);

//ȫ��ʱ��IO����
BUFIO BUFIO_inst (
    .I            (rgmii_rxc),      // 1-bit input: Clock input
    .O            (rgmii_rxc_bufio) // 1-bit output: Clock output
);

//����������±���DDR�źţ�ת������λ������SDR�ź�
IDDRE1 #(
    .DDR_CLK_EDGE     ("SAME_EDGE_PIPELINED"),
    .IS_CB_INVERTED   (1'b0),
    .IS_C_INVERTED    (1'b0)
)
IDDRE1_inst (
    .Q1    (gmii_rxdv_t[0]),     // 1-bit output: Registered parallel output 1
    .Q2    (gmii_rxdv_t[1]),     // 1-bit output: Registered parallel output 2
    .C     (rgmii_rxc_bufio),    // 1-bit input: High-speed clock
    .CB    (~rgmii_rxc_bufio),   // 1-bit input: Inversion of High-speed clock C
    .D     (rgmii_rx_ctl),       // 1-bit input: Serial Data Input
    .R     (1'b0)                // 1-bit input: Active High Async Reset
);

genvar i;
generate for (i=0; i<4; i=i+1)
    begin : rxdata_bus
        IDDRE1 #(
            .DDR_CLK_EDGE      ("SAME_EDGE_PIPELINED"),
            .IS_CB_INVERTED    (1'b0),
            .IS_C_INVERTED     (1'b0)
        )
        IDDRE1_inst (
            .Q1                (gmii_rxd[i]),    // ��4λ
            .Q2                (gmii_rxd[4+i]),  // ��4λ
            .C                 (rgmii_rxc_bufio),
            .CB                (~rgmii_rxc_bufio),
            .D                 (rgmii_rxd[i]),
            .R                 (1'b0)
        ); 
    end
endgenerate

endmodule