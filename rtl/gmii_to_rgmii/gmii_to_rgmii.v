//****************************************Copyright (c)***********************************//
//Copyright(C) 珊瑚伊斯特 2025.3
//All rights reserved                                  
//----------------------------------------------------------------------------------------
// File name:           gmii_to_rgmii
// Last modified Date:  
// Last Version:        
// Descriptions:        GMII接口转RGMII接口模块
//----------------------------------------------------------------------------------------
// Created by:          珊瑚伊斯特
// Created date:        2025.3
// Version:             V0.1
// Descriptions:        The original version
//
//----------------------------------------------------------------------------------------
//****************************************************************************************//

module gmii_to_rgmii(
    //以太网GMII接口    
    output             gmii_rx_clk , //GMII接收时钟
    output             gmii_rx_dv  , //GMII接收数据有效信号
    output      [7:0]  gmii_rxd    , //GMII接收数据
    output             gmii_tx_clk , //GMII发送时钟    
    input              gmii_tx_en  , //GMII发送数据使能信号
    input       [7:0]  gmii_txd    , //GMII发送数据            
    //以太网RGMII接口   
    input              rgmii_rxc   , //RGMII接收时钟
    input              rgmii_rx_ctl, //RGMII接收数据控制信号
    input       [3:0]  rgmii_rxd   , //RGMII接收数据
    output             rgmii_txc   , //RGMII发送时钟    
    output             rgmii_tx_ctl, //RGMII发送数据控制信号
    output      [3:0]  rgmii_txd   , //RGMII发送数据
    input       [1:0]  speed_mode    //速率模式：11-1000M，10-100M，01-10M
    );

// wire define
// wire    gmii_rx_er  ; //GMII接收错误信号
// wire    gmii_tx_er  ; //GMII发送错误信号   
 
assign gmii_tx_clk = gmii_rx_clk;
// 根据速率模式设置错误信号
// assign gmii_tx_er = (speed_mode == 2'b11) ? 1'b1 : 1'b0;
// assign gmii_rx_er = (speed_mode == 2'b11) ? 1'b1 : 1'b0;

//RGMII接收
rgmii_rx u_rgmii_rx(
    .gmii_rx_clk   (gmii_rx_clk ),
    .rgmii_rxc     (rgmii_rxc   ),
    .rgmii_rx_ctl  (rgmii_rx_ctl),
    .rgmii_rxd     (rgmii_rxd   ),
    // .gmii_rx_er    (gmii_rx_er  ),
    .gmii_rx_dv    (gmii_rx_dv ),
    .gmii_rxd      (gmii_rxd   )
    );

//RGMII发送
rgmii_tx u_rgmii_tx(
    .gmii_tx_clk   (gmii_tx_clk ),
    .gmii_tx_en    (gmii_tx_en  ),
    .gmii_txd      (gmii_txd    ),
    // .gmii_tx_er    (gmii_tx_er  ),
              
    .rgmii_txc     (rgmii_txc   ),
    .rgmii_tx_ctl  (rgmii_tx_ctl),
    .rgmii_txd     (rgmii_txd   )
    );

endmodule