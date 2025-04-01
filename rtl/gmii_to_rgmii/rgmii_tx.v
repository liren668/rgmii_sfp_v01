//****************************************Copyright (c)***********************************//
//��Ȩ���У�����ؾ���
//Copyright(C) ɺ����˹�� 2025.3
//All rights reserved                                  
//----------------------------------------------------------------------------------------
// File name:           rgmii_tx
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

module rgmii_tx(
    //GMII���Ͷ˿�
    input              gmii_tx_clk , //GMII����ʱ��    
    input              gmii_tx_en  , //GMII���������Ч�ź�
    input       [7:0]  gmii_txd    , //GMII�������   
    // input              gmii_tx_er  , //GMII�������ݴ����ź�
    //RGMII���Ͷ˿�
    output             rgmii_txc   , //RGMII��������ʱ��    
    output             rgmii_tx_ctl, //RGMII���������Ч�ź�
    output      [3:0]  rgmii_txd     //RGMII�������     
    );

//*****************************************************
//**                    main code
//*****************************************************

assign rgmii_txc = gmii_tx_clk;

//���˫�ز����Ĵ��� (rgmii_tx_ctl)
ODDRE1 #(
    .IS_C_INVERTED     (1'b0),            // Optional inversion for C
    .IS_D1_INVERTED    (1'b0),            // Unsupported, do not use
    .IS_D2_INVERTED    (1'b0),            // Unsupported, do not use
    .SIM_DEVICE        ("ULTRASCALE"),    // Set the device version
    .SRVAL             (1'b0)             // Initializes the ODDRE1 Flip-Flops
)
ODDRE1_tx_ctl (
    .Q     (rgmii_tx_ctl),                     // 1-bit output
    .C     (gmii_tx_clk),                      // clock input
    .D1    (gmii_tx_en),                       // ����������ʹ��
    .D2    (gmii_tx_en),                        // �½�������ʹ�� - 10M/100M/��Ч
    .SR    (1'b0)                              // reset
);

//RGMII��������
genvar i;
generate for (i=0; i<4; i=i+1)
    begin : txdata_bus
        ODDRE1 #(
            .IS_C_INVERTED(1'b0),      // Optional inversion for C
            .IS_D1_INVERTED(1'b0),     // Unsupported, do not use
            .IS_D2_INVERTED(1'b0),     // Unsupported, do not use
            .SIM_DEVICE("ULTRASCALE"), // Set the device version
            .SRVAL(1'b0)               // Initializes the ODDRE1 Flip-Flops
        )
        ODDRE1_inst (
            .Q     (rgmii_txd[i]),     // 1-bit output
            .C     (gmii_tx_clk),      // clock input
            .D1    (gmii_txd[i]),      // ��4λ����
            .D2    (gmii_txd[4+i]),    // ��4λ����
            .SR    (1'b0)              // reset
        );             
    end
endgenerate

endmodule