// Generated by https://github.com/bcrist/microbe-regz
const Mmio = @import("microbe").Mmio;

pub const ADDR_ENDP = packed struct(u32) {
    ADDRESS: u7 = 0,
    _reserved_7: u9 = 0,
    ENDPOINT: u4 = 0,
    _reserved_14: u5 = 0,
    INTEP_DIR: u1 = 0,
    INTEP_PREAMBLE: u1 = 0,
    _reserved_1b: u5 = 0,
};

pub const SOF_ = packed struct(u32) {
    COUNT: u11 = 0,
    _reserved_b: u21 = 0,
};

pub const USB_INT = packed struct(u32) {
    HOST_CONN_DIS: u1 = 0,
    HOST_RESUME: u1 = 0,
    HOST_SOF: u1 = 0,
    TRANS_COMPLETE: u1 = 0,
    BUFF_STATUS: u1 = 0,
    ERROR_DATA_SEQ: u1 = 0,
    ERROR_RX_TIMEOUT: u1 = 0,
    ERROR_RX_OVERFLOW: u1 = 0,
    ERROR_BIT_STUFF: u1 = 0,
    ERROR_CRC: u1 = 0,
    STALL: u1 = 0,
    VBUS_DETECT: u1 = 0,
    BUS_RESET: u1 = 0,
    DEV_CONN_DIS: u1 = 0,
    DEV_SUSPEND: u1 = 0,
    DEV_RESUME_FROM_HOST: u1 = 0,
    SETUP_REQ: u1 = 0,
    DEV_SOF: u1 = 0,
    ABORT_DONE: u1 = 0,
    EP_STALL_NAK: u1 = 0,
    _reserved_14: u12 = 0,
};

pub const EP_CONTROL = packed struct(u32) {
    BUFFER_ADDRESS: u16 = 0,
    INTERRUPT_ON_NAK: u1 = 0,
    INTERRUPT_ON_STALL: u1 = 0,
    _reserved_12: u8 = 0,
    ENDPOINT_TYPE: enum(u2) {
        Control = 0x0,
        Isochronous = 0x1,
        Bulk = 0x2,
        Interrupt = 0x3,
    } = .Control,
    INTERRUPT_PER_DOUBLE_BUFF: u1 = 0,
    INTERRUPT_PER_BUFF: u1 = 0,
    DOUBLE_BUFFERED: u1 = 0,
    ENABLE: u1 = 0,
};

pub const EP_BUFFER_CONTROL = packed struct(u32) {
    LENGTH_0: u10 = 0,
    AVAILABLE_0: u1 = 0,
    STALL: u1 = 0,
    RESET: u1 = 0,
    PID_0: u1 = 0,
    LAST_0: u1 = 0,
    FULL_0: u1 = 0,
    LENGTH_1: u10 = 0,
    AVAILABLE_1: u1 = 0,
    DOUBLE_BUFFER_ISO_OFFSET: enum(u2) {
        @"128" = 0x0,
        @"256" = 0x1,
        @"512" = 0x2,
        @"1024" = 0x3,
    } = .@"128",
    PID_1: u1 = 0,
    LAST_1: u1 = 0,
    FULL_1: u1 = 0,
};

pub const BUF = extern struct {
    SETUP_PACKET_LOW: Mmio(packed struct(u32) {
        BMREQUESTTYPE: u8 = 0,
        BREQUEST: u8 = 0,
        WVALUE: u16 = 0,
    }, .rw),
    SETUP_PACKET_HIGH: Mmio(packed struct(u32) {
        WINDEX: u16 = 0,
        WLENGTH: u16 = 0,
    }, .rw),
    EP1_IN_CONTROL: Mmio(EP_CONTROL, .rw),
    EP1_OUT_CONTROL: Mmio(EP_CONTROL, .rw),
    EP2_IN_CONTROL: Mmio(EP_CONTROL, .rw),
    EP2_OUT_CONTROL: Mmio(EP_CONTROL, .rw),
    EP3_IN_CONTROL: Mmio(EP_CONTROL, .rw),
    EP3_OUT_CONTROL: Mmio(EP_CONTROL, .rw),
    EP4_IN_CONTROL: Mmio(EP_CONTROL, .rw),
    EP4_OUT_CONTROL: Mmio(EP_CONTROL, .rw),
    EP5_IN_CONTROL: Mmio(EP_CONTROL, .rw),
    EP5_OUT_CONTROL: Mmio(EP_CONTROL, .rw),
    EP6_IN_CONTROL: Mmio(EP_CONTROL, .rw),
    EP6_OUT_CONTROL: Mmio(EP_CONTROL, .rw),
    EP7_IN_CONTROL: Mmio(EP_CONTROL, .rw),
    EP7_OUT_CONTROL: Mmio(EP_CONTROL, .rw),
    EP8_IN_CONTROL: Mmio(EP_CONTROL, .rw),
    EP8_OUT_CONTROL: Mmio(EP_CONTROL, .rw),
    EP9_IN_CONTROL: Mmio(EP_CONTROL, .rw),
    EP9_OUT_CONTROL: Mmio(EP_CONTROL, .rw),
    EP10_IN_CONTROL: Mmio(EP_CONTROL, .rw),
    EP10_OUT_CONTROL: Mmio(EP_CONTROL, .rw),
    EP11_IN_CONTROL: Mmio(EP_CONTROL, .rw),
    EP11_OUT_CONTROL: Mmio(EP_CONTROL, .rw),
    EP12_IN_CONTROL: Mmio(EP_CONTROL, .rw),
    EP12_OUT_CONTROL: Mmio(EP_CONTROL, .rw),
    EP13_IN_CONTROL: Mmio(EP_CONTROL, .rw),
    EP13_OUT_CONTROL: Mmio(EP_CONTROL, .rw),
    EP14_IN_CONTROL: Mmio(EP_CONTROL, .rw),
    EP14_OUT_CONTROL: Mmio(EP_CONTROL, .rw),
    EP15_IN_CONTROL: Mmio(EP_CONTROL, .rw),
    EP15_OUT_CONTROL: Mmio(EP_CONTROL, .rw),
    EP0_IN_BUFFER_CONTROL: Mmio(EP_BUFFER_CONTROL, .rw),
    EP0_OUT_BUFFER_CONTROL: Mmio(EP_BUFFER_CONTROL, .rw),
    EP1_IN_BUFFER_CONTROL: Mmio(EP_BUFFER_CONTROL, .rw),
    EP1_OUT_BUFFER_CONTROL: Mmio(EP_BUFFER_CONTROL, .rw),
    EP2_IN_BUFFER_CONTROL: Mmio(EP_BUFFER_CONTROL, .rw),
    EP2_OUT_BUFFER_CONTROL: Mmio(EP_BUFFER_CONTROL, .rw),
    EP3_IN_BUFFER_CONTROL: Mmio(EP_BUFFER_CONTROL, .rw),
    EP3_OUT_BUFFER_CONTROL: Mmio(EP_BUFFER_CONTROL, .rw),
    EP4_IN_BUFFER_CONTROL: Mmio(EP_BUFFER_CONTROL, .rw),
    EP4_OUT_BUFFER_CONTROL: Mmio(EP_BUFFER_CONTROL, .rw),
    EP5_IN_BUFFER_CONTROL: Mmio(EP_BUFFER_CONTROL, .rw),
    EP5_OUT_BUFFER_CONTROL: Mmio(EP_BUFFER_CONTROL, .rw),
    EP6_IN_BUFFER_CONTROL: Mmio(EP_BUFFER_CONTROL, .rw),
    EP6_OUT_BUFFER_CONTROL: Mmio(EP_BUFFER_CONTROL, .rw),
    EP7_IN_BUFFER_CONTROL: Mmio(EP_BUFFER_CONTROL, .rw),
    EP7_OUT_BUFFER_CONTROL: Mmio(EP_BUFFER_CONTROL, .rw),
    EP8_IN_BUFFER_CONTROL: Mmio(EP_BUFFER_CONTROL, .rw),
    EP8_OUT_BUFFER_CONTROL: Mmio(EP_BUFFER_CONTROL, .rw),
    EP9_IN_BUFFER_CONTROL: Mmio(EP_BUFFER_CONTROL, .rw),
    EP9_OUT_BUFFER_CONTROL: Mmio(EP_BUFFER_CONTROL, .rw),
    EP10_IN_BUFFER_CONTROL: Mmio(EP_BUFFER_CONTROL, .rw),
    EP10_OUT_BUFFER_CONTROL: Mmio(EP_BUFFER_CONTROL, .rw),
    EP11_IN_BUFFER_CONTROL: Mmio(EP_BUFFER_CONTROL, .rw),
    EP11_OUT_BUFFER_CONTROL: Mmio(EP_BUFFER_CONTROL, .rw),
    EP12_IN_BUFFER_CONTROL: Mmio(EP_BUFFER_CONTROL, .rw),
    EP12_OUT_BUFFER_CONTROL: Mmio(EP_BUFFER_CONTROL, .rw),
    EP13_IN_BUFFER_CONTROL: Mmio(EP_BUFFER_CONTROL, .rw),
    EP13_OUT_BUFFER_CONTROL: Mmio(EP_BUFFER_CONTROL, .rw),
    EP14_IN_BUFFER_CONTROL: Mmio(EP_BUFFER_CONTROL, .rw),
    EP14_OUT_BUFFER_CONTROL: Mmio(EP_BUFFER_CONTROL, .rw),
    EP15_IN_BUFFER_CONTROL: Mmio(EP_BUFFER_CONTROL, .rw),
    EP15_OUT_BUFFER_CONTROL: Mmio(EP_BUFFER_CONTROL, .rw),
};

pub const EndpointBitmap = packed struct(u32) {
    EP0_IN: u1 = 0,
    EP0_OUT: u1 = 0,
    EP1_IN: u1 = 0,
    EP1_OUT: u1 = 0,
    EP2_IN: u1 = 0,
    EP2_OUT: u1 = 0,
    EP3_IN: u1 = 0,
    EP3_OUT: u1 = 0,
    EP4_IN: u1 = 0,
    EP4_OUT: u1 = 0,
    EP5_IN: u1 = 0,
    EP5_OUT: u1 = 0,
    EP6_IN: u1 = 0,
    EP6_OUT: u1 = 0,
    EP7_IN: u1 = 0,
    EP7_OUT: u1 = 0,
    EP8_IN: u1 = 0,
    EP8_OUT: u1 = 0,
    EP9_IN: u1 = 0,
    EP9_OUT: u1 = 0,
    EP10_IN: u1 = 0,
    EP10_OUT: u1 = 0,
    EP11_IN: u1 = 0,
    EP11_OUT: u1 = 0,
    EP12_IN: u1 = 0,
    EP12_OUT: u1 = 0,
    EP13_IN: u1 = 0,
    EP13_OUT: u1 = 0,
    EP14_IN: u1 = 0,
    EP14_OUT: u1 = 0,
    EP15_IN: u1 = 0,
    EP15_OUT: u1 = 0,
};

pub const REGS = extern struct {
    ADDR_ENDP: Mmio(packed struct(u32) {
        ADDRESS: u7 = 0,
        _reserved_7: u9 = 0,
        ENDPOINT: u4 = 0,
        _reserved_14: u12 = 0,
    }, .rw),
    ADDR_ENDP1: Mmio(ADDR_ENDP, .rw),
    ADDR_ENDP2: Mmio(ADDR_ENDP, .rw),
    ADDR_ENDP3: Mmio(ADDR_ENDP, .rw),
    ADDR_ENDP4: Mmio(ADDR_ENDP, .rw),
    ADDR_ENDP5: Mmio(ADDR_ENDP, .rw),
    ADDR_ENDP6: Mmio(ADDR_ENDP, .rw),
    ADDR_ENDP7: Mmio(ADDR_ENDP, .rw),
    ADDR_ENDP8: Mmio(ADDR_ENDP, .rw),
    ADDR_ENDP9: Mmio(ADDR_ENDP, .rw),
    ADDR_ENDP10: Mmio(ADDR_ENDP, .rw),
    ADDR_ENDP11: Mmio(ADDR_ENDP, .rw),
    ADDR_ENDP12: Mmio(ADDR_ENDP, .rw),
    ADDR_ENDP13: Mmio(ADDR_ENDP, .rw),
    ADDR_ENDP14: Mmio(ADDR_ENDP, .rw),
    ADDR_ENDP15: Mmio(ADDR_ENDP, .rw),
    MAIN_CTRL: Mmio(packed struct(u32) {
        CONTROLLER_EN: u1 = 0,
        HOST_NDEVICE: u1 = 0,
        _reserved_2: u29 = 0,
        SIM_TIMING: u1 = 0,
    }, .rw),
    SOF_WR: Mmio(SOF_, .rw),
    SOF_RD: Mmio(SOF_, .rw),
    SIE_CTRL: Mmio(packed struct(u32) {
        START_TRANS: u1 = 0,
        SEND_SETUP: u1 = 0,
        SEND_DATA: u1 = 0,
        RECEIVE_DATA: u1 = 0,
        STOP_TRANS: u1 = 0,
        _reserved_5: u1 = 0,
        PREAMBLE_EN: u1 = 0,
        _reserved_7: u1 = 0,
        SOF_SYNC: u1 = 0,
        SOF_EN: u1 = 0,
        KEEP_ALIVE_EN: u1 = 0,
        VBUS_EN: u1 = 0,
        RESUME: u1 = 0,
        RESET_BUS: u1 = 0,
        _reserved_e: u1 = 0,
        PULLDOWN_EN: u1 = 0,
        PULLUP_EN: u1 = 0,
        RPU_OPT: u1 = 0,
        TRANSCEIVER_PD: u1 = 0,
        _reserved_13: u5 = 0,
        DIRECT_DM: u1 = 0,
        DIRECT_DP: u1 = 0,
        DIRECT_EN: u1 = 0,
        EP0_INT_NAK: u1 = 0,
        EP0_INT_2BUF: u1 = 0,
        EP0_INT_1BUF: u1 = 0,
        EP0_DOUBLE_BUF: u1 = 0,
        EP0_INT_STALL: u1 = 0,
    }, .rw),
    SIE_STATUS: Mmio(packed struct(u32) {
        VBUS_DETECTED: u1 = 0,
        _reserved_1: u1 = 0,
        LINE_STATE: u2 = 0,
        SUSPENDED: u1 = 0,
        _reserved_5: u3 = 0,
        SPEED: u2 = 0,
        VBUS_OVER_CURR: u1 = 0,
        RESUME: u1 = 0,
        _reserved_c: u4 = 0,
        CONNECTED: u1 = 0,
        SETUP_REC: u1 = 0,
        TRANS_COMPLETE: u1 = 0,
        BUS_RESET: u1 = 0,
        _reserved_14: u4 = 0,
        CRC_ERROR: u1 = 0,
        BIT_STUFF_ERROR: u1 = 0,
        RX_OVERFLOW: u1 = 0,
        RX_TIMEOUT: u1 = 0,
        NAK_REC: u1 = 0,
        STALL_REC: u1 = 0,
        ACK_REC: u1 = 0,
        DATA_SEQ_ERROR: u1 = 0,
    }, .rw),
    INT_EP_CTRL: Mmio(packed struct(u32) {
        _reserved_0: u1 = 0,
        INT_EP_ACTIVE: u15 = 0,
        _reserved_10: u16 = 0,
    }, .rw),
    BUFF_STATUS: Mmio(EndpointBitmap, .rw),
    BUFF_CPU_SHOULD_HANDLE: Mmio(EndpointBitmap, .rw),
    EP_ABORT: Mmio(EndpointBitmap, .rw),
    EP_ABORT_DONE: Mmio(EndpointBitmap, .rw),
    EP_STALL_ARM: Mmio(packed struct(u32) {
        EP0_IN: u1 = 0,
        EP0_OUT: u1 = 0,
        _reserved_2: u30 = 0,
    }, .rw),
    NAK_POLL: Mmio(packed struct(u32) {
        DELAY_LS: u10 = 0x10,
        _reserved_a: u6 = 0,
        DELAY_FS: u10 = 0x10,
        _reserved_1a: u6 = 0,
    }, .rw),
    EP_STATUS_STALL_NAK: Mmio(EndpointBitmap, .rw),
    USB_MUXING: Mmio(packed struct(u32) {
        TO_PHY: u1 = 0,
        TO_EXTPHY: u1 = 0,
        TO_DIGITAL_PAD: u1 = 0,
        SOFTCON: u1 = 0,
        _reserved_4: u28 = 0,
    }, .rw),
    USB_PWR: Mmio(packed struct(u32) {
        VBUS_EN: u1 = 0,
        VBUS_EN_OVERRIDE_EN: u1 = 0,
        VBUS_DETECT: u1 = 0,
        VBUS_DETECT_OVERRIDE_EN: u1 = 0,
        OVERCURR_DETECT: u1 = 0,
        OVERCURR_DETECT_EN: u1 = 0,
        _reserved_6: u26 = 0,
    }, .rw),
    USBPHY_DIRECT: Mmio(packed struct(u32) {
        DP_PULLUP_HISEL: u1 = 0,
        DP_PULLUP_EN: u1 = 0,
        DP_PULLDN_EN: u1 = 0,
        _reserved_3: u1 = 0,
        DM_PULLUP_HISEL: u1 = 0,
        DM_PULLUP_EN: u1 = 0,
        DM_PULLDN_EN: u1 = 0,
        _reserved_7: u1 = 0,
        TX_DP_OE: u1 = 0,
        TX_DM_OE: u1 = 0,
        TX_DP: u1 = 0,
        TX_DM: u1 = 0,
        RX_PD: u1 = 0,
        TX_PD: u1 = 0,
        TX_FSSLEW: u1 = 0,
        TX_DIFFMODE: u1 = 0,
        RX_DD: u1 = 0,
        RX_DP: u1 = 0,
        RX_DM: u1 = 0,
        DP_OVCN: u1 = 0,
        DM_OVCN: u1 = 0,
        DP_OVV: u1 = 0,
        DM_OVV: u1 = 0,
        _reserved_17: u9 = 0,
    }, .rw),
    USBPHY_DIRECT_OVERRIDE: Mmio(packed struct(u32) {
        DP_PULLUP_HISEL_OVERRIDE_EN: u1 = 0,
        DM_PULLUP_HISEL_OVERRIDE_EN: u1 = 0,
        DP_PULLUP_EN_OVERRIDE_EN: u1 = 0,
        DP_PULLDN_EN_OVERRIDE_EN: u1 = 0,
        DM_PULLDN_EN_OVERRIDE_EN: u1 = 0,
        TX_DP_OE_OVERRIDE_EN: u1 = 0,
        TX_DM_OE_OVERRIDE_EN: u1 = 0,
        TX_DP_OVERRIDE_EN: u1 = 0,
        TX_DM_OVERRIDE_EN: u1 = 0,
        RX_PD_OVERRIDE_EN: u1 = 0,
        TX_PD_OVERRIDE_EN: u1 = 0,
        TX_FSSLEW_OVERRIDE_EN: u1 = 0,
        DM_PULLUP_OVERRIDE_EN: u1 = 0,
        _reserved_d: u2 = 0,
        TX_DIFFMODE_OVERRIDE_EN: u1 = 0,
        _reserved_10: u16 = 0,
    }, .rw),
    USBPHY_TRIM: Mmio(packed struct(u32) {
        DP_PULLDN_TRIM: u5 = 0x1F,
        _reserved_5: u3 = 0,
        DM_PULLDN_TRIM: u5 = 0x1F,
        _reserved_d: u19 = 0,
    }, .rw),
    _reserved_88: [4]u8 = undefined,
    INTR: Mmio(USB_INT, .rw),
    INTE: Mmio(USB_INT, .rw),
    INTF: Mmio(USB_INT, .rw),
    INTS: Mmio(USB_INT, .rw),
};
