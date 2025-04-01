//----------------------------------------------------------------------------------------
// File name:           rgmii_sfp_exchange
// Created by:          珊瑚伊斯特
// Created date:        2025.3
// Version:             V0.1
// Descriptions:        rgmii_sfp_exchange
//rgmii接口到SFP接口的转换器。
//----------------------------------------------------------------------------------------

module rgmii_sfp_exchange(
    // 系统接口
    input           sys_clk_p,        // 系统时钟正端100MHz
    input           sys_clk_n,        // 系统时钟负端  
    input           sys_rst_n,        // 系统复位,低电平有效

    // MDIO接口
    output          eth_mdc,          // MDIO时钟
    inout           eth_mdio,         // MDIO数据 
    input           key,              // MDIO软复位触发
    output   [1:0]  led,              // LED连接速率指示
    // output          eth_rst_n,        // PHY复位,低电平有效

    // RGMII接口
    input           rgmii_rxc,        // 接收时钟2.5MHz,25MHz,125MHz
    input           rgmii_rx_ctl,     // 接收控制
    input    [3:0]  rgmii_rxd,        // 接收数据
    output          rgmii_txc,        // 发送时钟2.5MHz,25MHz,125MHz   
    output          rgmii_tx_ctl,     // 发送控制 
    output   [3:0]  rgmii_txd,        // 发送数据

    // SFP接口
    input           q0_ck1_n_in,      // 参考时钟负端156.25MHz
    input           q0_ck1_p_in,      // 参考时钟正端
    input           rxn_in,           // 差分接收负端
    input           rxp_in,           // 差分接收正端
    output          txn_out,          // 差分发送负端
    output          txp_out,          // 差分发送正端
    output  [1:0]   tx_disable     // 发送使能    
);


// 时钟和复位
wire          clk_ila;                // ILA调试时钟62.5MHz
wire          dclk;                   // 内部时钟100MHz
wire          locked;                 // 时钟锁定
wire          tx_clk_out;             // 发送时钟
wire          gt_refclk_out;          // 参考时钟
wire   [1:0]  speed_mode;             // 速率模式

// GMII接口 
wire          gmii_rx_clk;            // 接收时钟2.5MHz,25MHz,125MHz
wire          gmii_rx_dv;             // 接收有效
wire   [7:0]  gmii_rxd;               // 接收数据
wire          gmii_tx_clk;            // 发送时钟2.5MHz,25MHz,125MHz  
wire          gmii_tx_en;             // 发送有效
wire   [7:0]  gmii_txd;              // 发送数据

// RGMII到SFP的AXI接口
wire          rgmii_axis_tvalid;      // 数据有效
wire   [63:0] rgmii_axis_tdata;       // 数据
wire          rgmii_axis_tlast;       // 最后一拍
wire   [7:0]  rgmii_axis_tkeep;       // 字节有效
wire          rgmii_axis_tready;      // 
wire          gt0_rst;                // GT0复位

// SFP到RGMII的AXI接口  
wire          sfp_axis_tvalid;        // 数据有效
wire   [63:0] sfp_axis_tdata;         // 数据
wire          sfp_axis_tlast;         // 最后一拍
wire   [7:0]  sfp_axis_tkeep;         // 字节有效
// wire          sfp_axis_tready;        // 准备就绪

// MDIO控制接口
wire          op_done;                // 操作完成
wire   [15:0] op_rd_data;            // 读数据
wire          op_rd_ack;             // 读应答
wire          op_exec;               // 执行
wire          op_rh_wl;              // 读写选择
wire   [4:0]  op_addr;               // 寄存器地址
wire   [15:0] op_wr_data;            // 写数据

// ILA实例化
// ila_0 u_ila_0 (
// 	.clk(clk_ila),                  // input wire clk 62.5MHZ

// 	.probe0(gmii_rx_clk),           // input wire [0:0]  probe0 125MHZ 
// 	.probe1(gmii_rx_dv),            // input wire [0:0]  probe1 
// 	.probe2(gmii_rxd),              // input wire [7:0]  probe2 
// 	.probe3(rgmii_axis_tvalid),           // input wire [0:0]  probe3 125MHZ
// 	.probe4(rgmii_axis_tdata),            // input wire [63:0]  probe4 
// 	.probe5(rgmii_axis_tlast),               // input wire [0:0]  probe5 
// 	.probe6(rgmii_axis_tkeep),          // input wire [7:0]  probe6 
// 	.probe7(rgmii_axis_tready),     // input wire [0:0]  probe7	
// 	.probe8(tx_clk_out)             // input wire [0:0]  probe7	
// );

// ila_0 u_ila_0 (
// 	.clk(clk_ila),                  // input wire clk 62.5MHZ

// 	.probe0(gmii_rx_dv),            // input wire [0:0]  probe1 
// 	.probe1(rgmii_axis_tvalid),           // input wire [0:0]  probe3 125MHZ
// 	.probe2(rgmii_axis_tdata),            // input wire [63:0]  probe4 
// 	.probe3(rgmii_axis_tlast),               // input wire [0:0]  probe5 
// 	.probe4(rgmii_axis_tkeep),          // input wire [7:0]  probe6 
// 	// .probe5(rgmii_axis_tready),     // input wire [0:0]  probe7	
// 	.probe5(tx_clk_out)             // input wire [0:0]  probe7	
// );


// PHY复位和SFP配置
// assign eth_rst_n = sys_rst_n;
assign tx_disable = 2'b00;

clk_wiz_0 u_clk_wiz_0(
    .clk_out1      (dclk),                // 内部时钟100MHz
    .clk_out2      (clk_ila),             // ILA调试时钟250MHz
    .reset         (~sys_rst_n),
    .locked        (locked),
    .clk_in1_p     (sys_clk_p),
    .clk_in1_n     (sys_clk_n)
);

// 实例化MDIO顶层模块
mdio_top u_mdio_top(
    .dclk          (dclk),         // 使用clk_wiz_0的输出时钟
    .sys_rst_n     (sys_rst_n),
    .eth_mdc       (eth_mdc),
    .eth_mdio      (eth_mdio),
    .key            (key),
    .led            (led),
    .speed_mode     (speed_mode)
);

// GMII-RGMII转换
gmii_to_rgmii u_gmii_to_rgmii(
    // GMII接口
    .gmii_rx_clk   (gmii_rx_clk),
    .gmii_rx_dv    (gmii_rx_dv),
    .gmii_rxd      (gmii_rxd),
    .gmii_tx_clk   (gmii_tx_clk),
    .gmii_tx_en    (gmii_tx_en), 
    .gmii_txd      (gmii_txd),
    // RGMII接口
    .rgmii_rxc     (rgmii_rxc),
    .rgmii_rx_ctl  (rgmii_rx_ctl),
    .rgmii_rxd     (rgmii_rxd),
    .rgmii_txc     (rgmii_txc),
    .rgmii_tx_ctl  (rgmii_tx_ctl),
    .rgmii_txd     (rgmii_txd),
    // 配置
    .speed_mode    (speed_mode)
);

// GMII转AXI 
gmii_to_axi u_gmii_to_axi(
    .gmii_rx_clk    (gmii_rx_clk),
    .tx_clk_out     (tx_clk_out),
    .rst_n          (sys_rst_n),
    .gmii_rx_dv     (gmii_rx_dv),
    .gmii_rxd       (gmii_rxd),
    .axis_tvalid    (rgmii_axis_tvalid),
    .axis_tdata     (rgmii_axis_tdata),
    .axis_tlast     (rgmii_axis_tlast),
    .axis_tkeep     (rgmii_axis_tkeep),
    .axis_tready    (rgmii_axis_tready),
   .clk_ila        (clk_ila)         // ILA时钟62.5MHz
);

// AXI转GMII
axi_to_gmii u_axi_to_gmii(    
    .rst_n          (sys_rst_n),
    .tx_clk_out     (tx_clk_out), 
    .gmii_tx_clk    (gmii_tx_clk),
    .axis_tvalid    (sfp_axis_tvalid),
    .axis_tdata     (sfp_axis_tdata),
    .axis_tlast     (sfp_axis_tlast),
    .axis_tkeep     (sfp_axis_tkeep),
    // .axis_tready    (sfp_axis_tready),
    .gmii_tx_en     (gmii_tx_en),
    .gmii_txd       (gmii_txd)
);

// 以太网核例化
xxv_ethernet_0 u_xxv_ethernet_0(
    // GT接口
    .gt_rxp_in_0             (rxp_in),
    .gt_rxn_in_0             (rxn_in),
    .gt_txp_out_0            (txp_out),
    .gt_txn_out_0            (txn_out),

    // 时钟接口
    .tx_clk_out_0            (tx_clk_out),
    .rx_clk_out_0            (), 
    .rx_core_clk_0           (tx_clk_out),
    .gt_refclk_p             (q0_ck1_p_in),         //156.25MHz
    .gt_refclk_n             (q0_ck1_n_in),
    .gt_refclk_out           (gt_refclk_out),   

    // 复位和配置
    .sys_reset               (~sys_rst_n), 
    .dclk                    (dclk),
    .txoutclksel_in_0        (3'b101),
    .rxoutclksel_in_0        (3'b101),
    .gtwiz_reset_tx_datapath_0  (1'b0),
    .gtwiz_reset_rx_datapath_0  (1'b0),
    .gt_loopback_in_0        (3'b000),
    .qpllreset_in_0          (1'b0),
    .tx_reset_0              (gt0_rst),
    .rx_reset_0              (gt0_rst),
    .rxrecclkout_0           ( ),    // output wire rxrecclkout_0
    .user_tx_reset_0          (),
    .user_rx_reset_0          (),
    
    // 状态
    .gtpowergood_out_0       (),

    // AXI Stream接收
    .rx_axis_tvalid_0        (sfp_axis_tvalid),
    .rx_axis_tdata_0         (sfp_axis_tdata), 
    .rx_axis_tlast_0         (sfp_axis_tlast),
    .rx_axis_tkeep_0         (sfp_axis_tkeep),
    .rx_axis_tuser_0         (1'b0),

    // AXI Stream发送
    .tx_axis_tready_0        (rgmii_axis_tready),
    .tx_axis_tvalid_0        (rgmii_axis_tvalid),
    .tx_axis_tdata_0         (rgmii_axis_tdata),
    .tx_axis_tlast_0         (rgmii_axis_tlast), 
    .tx_axis_tkeep_0         (rgmii_axis_tkeep),
    .tx_axis_tuser_0         (1'b0),

    //RX 控制信号
    .ctl_rx_enable_0                  (1'b1), // 使能接收功能
    .ctl_rx_check_preamble_0          (1'b0), // 不检查前导码(7个0x55)
    .ctl_rx_check_sfd_0               (1'b0), // 不检查帧起始定界符(0xD5)
    .ctl_rx_force_resync_0            (1'b0), // input wire ctl_rx_force_resync_0
    .ctl_rx_delete_fcs_0              (1'b1), // // 删除接收数据的FCS字段
    .ctl_rx_ignore_fcs_0              (1'b1), // // 忽略FCS检查
    .ctl_rx_max_packet_len_0          (15'd9600), // input wire [14 : 0] ctl_rx_max_packet_len_0
    .ctl_rx_min_packet_len_0          (15'd64 ),  // input wire [7 : 0] ctl_rx_min_packet_len_0
    .ctl_rx_process_lfi_0             (1'b0), // input wire ctl_rx_process_lfi_0
    .ctl_rx_test_pattern_0            (1'b0), // input wire ctl_rx_test_pattern_0
    .ctl_rx_data_pattern_select_0     (1'b0), // input wire ctl_rx_data_pattern_select_0
    .ctl_rx_test_pattern_enable_0     (1'b0), // input wire ctl_rx_test_pattern_enable_0
    .ctl_rx_custom_preamble_enable_0  (1'b0), // input wire ctl_rx_custom_preamble_enable_0

    //AXI4?Stream 接口 - TX 路径控制信号和状态信号
    .ctl_tx_enable_0                  (1'b1),     // input wire ctl_tx_enable_0
    .ctl_tx_send_rfi_0                (1'b0),     // input wire ctl_tx_send_rfi_0
    .ctl_tx_send_lfi_0                (1'b0),     // input wire ctl_tx_send_lfi_0
    .ctl_tx_send_idle_0               (1'b0),     // input wire ctl_tx_send_idle_0
    .ctl_tx_fcs_ins_enable_0          (1'b0),     // input wire ctl_tx_fcs_ins_enable_0
    .ctl_tx_ignore_fcs_0              (1'b0),     // input wire ctl_tx_ignore_fcs_0
    
    .ctl_tx_test_pattern_0            (1'b0),     // input wire ctl_tx_test_pattern_0
    .ctl_tx_test_pattern_enable_0     (1'b0),     // input wire ctl_tx_test_pattern_enable_0
    .ctl_tx_test_pattern_select_0     (1'b0),     // input wire ctl_tx_test_pattern_select_0
    .ctl_tx_data_pattern_select_0     (1'b0),     // input wire ctl_tx_data_pattern_select_0
    .ctl_tx_test_pattern_seed_a_0     (1'b0),     // input wire [57 : 0] ctl_tx_test_pattern_seed_a_0
    .ctl_tx_test_pattern_seed_b_0     (1'b0),     // input wire [57 : 0] ctl_tx_test_pattern_seed_b_0
    .ctl_tx_ipg_value_0               (4'd12),    // input wire [3 : 0] ctl_tx_ipg_value_0
    
    .ctl_tx_custom_preamble_enable_0  (1'b0)     // input wire ctl_tx_custom_preamble_enable_0
);
endmodule