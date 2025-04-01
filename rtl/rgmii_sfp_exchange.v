//----------------------------------------------------------------------------------------
// File name:           rgmii_sfp_exchange
// Created by:          ɺ����˹��
// Created date:        2025.3
// Version:             V0.1
// Descriptions:        rgmii_sfp_exchange
//rgmii�ӿڵ�SFP�ӿڵ�ת������
//----------------------------------------------------------------------------------------

module rgmii_sfp_exchange(
    // ϵͳ�ӿ�
    input           sys_clk_p,        // ϵͳʱ������100MHz
    input           sys_clk_n,        // ϵͳʱ�Ӹ���  
    input           sys_rst_n,        // ϵͳ��λ,�͵�ƽ��Ч

    // MDIO�ӿ�
    output          eth_mdc,          // MDIOʱ��
    inout           eth_mdio,         // MDIO���� 
    input           key,              // MDIO��λ����
    output   [1:0]  led,              // LED��������ָʾ
    // output          eth_rst_n,        // PHY��λ,�͵�ƽ��Ч

    // RGMII�ӿ�
    input           rgmii_rxc,        // ����ʱ��2.5MHz,25MHz,125MHz
    input           rgmii_rx_ctl,     // ���տ���
    input    [3:0]  rgmii_rxd,        // ��������
    output          rgmii_txc,        // ����ʱ��2.5MHz,25MHz,125MHz   
    output          rgmii_tx_ctl,     // ���Ϳ��� 
    output   [3:0]  rgmii_txd,        // ��������

    // SFP�ӿ�
    input           q0_ck1_n_in,      // �ο�ʱ�Ӹ���156.25MHz
    input           q0_ck1_p_in,      // �ο�ʱ������
    input           rxn_in,           // ��ֽ��ո���
    input           rxp_in,           // ��ֽ�������
    output          txn_out,          // ��ַ��͸���
    output          txp_out,          // ��ַ�������
    output  [1:0]   tx_disable     // ����ʹ��    
);


// ʱ�Ӻ͸�λ
wire          clk_ila;                // ILA����ʱ��62.5MHz
wire          dclk;                   // �ڲ�ʱ��100MHz
wire          locked;                 // ʱ������
wire          tx_clk_out;             // ����ʱ��
wire          gt_refclk_out;          // �ο�ʱ��
wire   [1:0]  speed_mode;             // ����ģʽ

// GMII�ӿ� 
wire          gmii_rx_clk;            // ����ʱ��2.5MHz,25MHz,125MHz
wire          gmii_rx_dv;             // ������Ч
wire   [7:0]  gmii_rxd;               // ��������
wire          gmii_tx_clk;            // ����ʱ��2.5MHz,25MHz,125MHz  
wire          gmii_tx_en;             // ������Ч
wire   [7:0]  gmii_txd;              // ��������

// RGMII��SFP��AXI�ӿ�
wire          rgmii_axis_tvalid;      // ������Ч
wire   [63:0] rgmii_axis_tdata;       // ����
wire          rgmii_axis_tlast;       // ���һ��
wire   [7:0]  rgmii_axis_tkeep;       // �ֽ���Ч
wire          rgmii_axis_tready;      // 
wire          gt0_rst;                // GT0��λ

// SFP��RGMII��AXI�ӿ�  
wire          sfp_axis_tvalid;        // ������Ч
wire   [63:0] sfp_axis_tdata;         // ����
wire          sfp_axis_tlast;         // ���һ��
wire   [7:0]  sfp_axis_tkeep;         // �ֽ���Ч
// wire          sfp_axis_tready;        // ׼������

// MDIO���ƽӿ�
wire          op_done;                // �������
wire   [15:0] op_rd_data;            // ������
wire          op_rd_ack;             // ��Ӧ��
wire          op_exec;               // ִ��
wire          op_rh_wl;              // ��дѡ��
wire   [4:0]  op_addr;               // �Ĵ�����ַ
wire   [15:0] op_wr_data;            // д����

// ILAʵ����
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


// PHY��λ��SFP����
// assign eth_rst_n = sys_rst_n;
assign tx_disable = 2'b00;

clk_wiz_0 u_clk_wiz_0(
    .clk_out1      (dclk),                // �ڲ�ʱ��100MHz
    .clk_out2      (clk_ila),             // ILA����ʱ��250MHz
    .reset         (~sys_rst_n),
    .locked        (locked),
    .clk_in1_p     (sys_clk_p),
    .clk_in1_n     (sys_clk_n)
);

// ʵ����MDIO����ģ��
mdio_top u_mdio_top(
    .dclk          (dclk),         // ʹ��clk_wiz_0�����ʱ��
    .sys_rst_n     (sys_rst_n),
    .eth_mdc       (eth_mdc),
    .eth_mdio      (eth_mdio),
    .key            (key),
    .led            (led),
    .speed_mode     (speed_mode)
);

// GMII-RGMIIת��
gmii_to_rgmii u_gmii_to_rgmii(
    // GMII�ӿ�
    .gmii_rx_clk   (gmii_rx_clk),
    .gmii_rx_dv    (gmii_rx_dv),
    .gmii_rxd      (gmii_rxd),
    .gmii_tx_clk   (gmii_tx_clk),
    .gmii_tx_en    (gmii_tx_en), 
    .gmii_txd      (gmii_txd),
    // RGMII�ӿ�
    .rgmii_rxc     (rgmii_rxc),
    .rgmii_rx_ctl  (rgmii_rx_ctl),
    .rgmii_rxd     (rgmii_rxd),
    .rgmii_txc     (rgmii_txc),
    .rgmii_tx_ctl  (rgmii_tx_ctl),
    .rgmii_txd     (rgmii_txd),
    // ����
    .speed_mode    (speed_mode)
);

// GMIIתAXI 
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
   .clk_ila        (clk_ila)         // ILAʱ��62.5MHz
);

// AXIתGMII
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

// ��̫��������
xxv_ethernet_0 u_xxv_ethernet_0(
    // GT�ӿ�
    .gt_rxp_in_0             (rxp_in),
    .gt_rxn_in_0             (rxn_in),
    .gt_txp_out_0            (txp_out),
    .gt_txn_out_0            (txn_out),

    // ʱ�ӽӿ�
    .tx_clk_out_0            (tx_clk_out),
    .rx_clk_out_0            (), 
    .rx_core_clk_0           (tx_clk_out),
    .gt_refclk_p             (q0_ck1_p_in),         //156.25MHz
    .gt_refclk_n             (q0_ck1_n_in),
    .gt_refclk_out           (gt_refclk_out),   

    // ��λ������
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
    
    // ״̬
    .gtpowergood_out_0       (),

    // AXI Stream����
    .rx_axis_tvalid_0        (sfp_axis_tvalid),
    .rx_axis_tdata_0         (sfp_axis_tdata), 
    .rx_axis_tlast_0         (sfp_axis_tlast),
    .rx_axis_tkeep_0         (sfp_axis_tkeep),
    .rx_axis_tuser_0         (1'b0),

    // AXI Stream����
    .tx_axis_tready_0        (rgmii_axis_tready),
    .tx_axis_tvalid_0        (rgmii_axis_tvalid),
    .tx_axis_tdata_0         (rgmii_axis_tdata),
    .tx_axis_tlast_0         (rgmii_axis_tlast), 
    .tx_axis_tkeep_0         (rgmii_axis_tkeep),
    .tx_axis_tuser_0         (1'b0),

    //RX �����ź�
    .ctl_rx_enable_0                  (1'b1), // ʹ�ܽ��չ���
    .ctl_rx_check_preamble_0          (1'b0), // �����ǰ����(7��0x55)
    .ctl_rx_check_sfd_0               (1'b0), // �����֡��ʼ�����(0xD5)
    .ctl_rx_force_resync_0            (1'b0), // input wire ctl_rx_force_resync_0
    .ctl_rx_delete_fcs_0              (1'b1), // // ɾ���������ݵ�FCS�ֶ�
    .ctl_rx_ignore_fcs_0              (1'b1), // // ����FCS���
    .ctl_rx_max_packet_len_0          (15'd9600), // input wire [14 : 0] ctl_rx_max_packet_len_0
    .ctl_rx_min_packet_len_0          (15'd64 ),  // input wire [7 : 0] ctl_rx_min_packet_len_0
    .ctl_rx_process_lfi_0             (1'b0), // input wire ctl_rx_process_lfi_0
    .ctl_rx_test_pattern_0            (1'b0), // input wire ctl_rx_test_pattern_0
    .ctl_rx_data_pattern_select_0     (1'b0), // input wire ctl_rx_data_pattern_select_0
    .ctl_rx_test_pattern_enable_0     (1'b0), // input wire ctl_rx_test_pattern_enable_0
    .ctl_rx_custom_preamble_enable_0  (1'b0), // input wire ctl_rx_custom_preamble_enable_0

    //AXI4?Stream �ӿ� - TX ·�������źź�״̬�ź�
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