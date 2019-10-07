/*
    This SDRAM controller is for the Mojo's SDRAM shield which uses
    a 48LC32M8A2-7E SDRAM chip. This module was designed under the
    assumption that the click rate is 100MHz. Timing values would
    need to be re-evaluated under different clock rates.

    This controller features two baisc improvements over the most
    basic of controllers. It does burst reads and writes of 4 bytes,
    and it only closes a row when it has to.
*/

module sdram (
        input clk,
        input rst,

        // these signals go directly to the IO pins
        output sdram_clk,
        output sdram_cle,
        output sdram_cs,
        output sdram_cas,
        output sdram_ras,
        output sdram_we,
        output sdram_dqm,
        output [1:0] sdram_ba,
        output [12:0] sdram_a,
        inout [7:0] sdram_dq,

        // User interface
        input [22:0] addr,      // address to read/write
        input rw,               // 1 = write, 0 = read
        input [31:0] data_in,   // data from a read
        output [31:0] data_out, // data for a write
        output busy,            // controller is busy when high
        input in_valid,         // pulse high to initiate a read/write
        output out_valid        // pulses high when data from read is valid
    );

    // Commands for the SDRAM
    localparam CMD_UNSELECTED    = 4'b1000;
    localparam CMD_NOP           = 4'b0111;
    localparam CMD_ACTIVE        = 4'b0011;
    localparam CMD_READ          = 4'b0101;
    localparam CMD_WRITE         = 4'b0100;
    localparam CMD_TERMINATE     = 4'b0110;
    localparam CMD_PRECHARGE     = 4'b0010;
    localparam CMD_REFRESH       = 4'b0001;
    localparam CMD_LOAD_MODE_REG = 4'b0000;

    localparam STATE_SIZE = 4;
    localparam INIT = 0,
               WAIT = 1,
               PRECHARGE_INIT = 2,
               REFRESH_INIT_1 = 3,
               REFRESH_INIT_2 = 4,
               LOAD_MODE_REG = 5,
               IDLE = 6,
               REFRESH = 7,
               ACTIVATE = 8,
               READ = 9,
               READ_RES = 10,
               WRITE = 11,
               PRECHARGE = 12;

    wire sdram_clk_ddr;

    // This is used to drive the SDRAM clock
    ODDR2 #(
        .DDR_ALIGNMENT("NONE"),
        .INIT(1'b0),
        .SRTYPE("SYNC")
    ) ODDR2_inst (
        .Q(sdram_clk_ddr), // 1-bit DDR output data
        .C0(clk), // 1-bit clock input
        .C1(~clk), // 1-bit clock input
        .CE(1'b1), // 1-bit clock enable input
        .D0(1'b0), // 1-bit data input (associated with C0)
        .D1(1'b1), // 1-bit data input (associated with C1)
        .R(1'b0), // 1-bit reset input
        .S(1'b0) // 1-bit set input
    );

    IODELAY2 #(
        .IDELAY_VALUE(0),
        .IDELAY_MODE("NORMAL"),
        .ODELAY_VALUE(100), // value of 100 seems to work at 100MHz
        .IDELAY_TYPE("FIXED"),
        .DELAY_SRC("ODATAIN"),
        .DATA_RATE("SDR")
    ) IODELAY_inst (
        .IDATAIN(1'b0),
        .T(1'b0),
        .ODATAIN(sdram_clk_ddr),
        .CAL(1'b0),
        .IOCLK0(1'b0),
        .IOCLK1(1'b0),
        .CLK(1'b0),
        .INC(1'b0),
        .CE(1'b0),
        .RST(1'b0),
        .BUSY(),
        .DATAOUT(),
        .DATAOUT2(),
        .TOUT(),
        .DOUT(sdram_clk)
    );

    // registers for SDRAM signals
    reg cle_d, dqm_d;
    reg [3:0] cmd_d;
    reg [1:0] ba_d;
    reg [12:0] a_d;
    reg [7:0] dq_d;
    reg [7:0] dqi_d;

    // We want the output/input registers to be embedded in the
    // IO buffers so we set IOB to "TRUE". This is to ensure all
    // the signals are sent and received at the same time.
    (* IOB = "TRUE" *)
    reg cle_q, dqm_q;
    (* IOB = "TRUE" *)
    reg [3:0] cmd_q;
    (* IOB = "TRUE" *)
    reg [1:0] ba_q;
    (* IOB = "TRUE" *)
    reg [12:0] a_q;
    (* IOB = "TRUE" *)
    reg [7:0] dq_q;
    (* IOB = "TRUE" *)
    reg [7:0] dqi_q;
    reg dq_en_d, dq_en_q;

    // Output assignments
    assign sdram_cle = cle_q;
    assign sdram_cs = cmd_q[3];
    assign sdram_ras = cmd_q[2];
    assign sdram_cas = cmd_q[1];
    assign sdram_we = cmd_q[0];
    assign sdram_dqm = dqm_q;
    assign sdram_ba = ba_q;
    assign sdram_a = a_q;
    assign sdram_dq = dq_en_q ? dq_q : 8'hZZ; // only drive when dq_en_q is 1

    reg [STATE_SIZE-1:0] state_d, state_q = INIT;
    reg [STATE_SIZE-1:0] next_state_d, next_state_q;

    reg [22:0] addr_d, addr_q;
    reg [31:0] data_d, data_q;
    reg out_valid_d, out_valid_q;

    assign data_out = data_q;
    assign busy = !ready_q;
    assign out_valid = out_valid_q;

    reg [15:0] delay_ctr_d, delay_ctr_q;
    reg [1:0] byte_ctr_d, byte_ctr_q;

    reg [9:0] refresh_ctr_d, refresh_ctr_q;
    reg refresh_flag_d, refresh_flag_q;

    reg ready_d, ready_q;
    reg saved_rw_d, saved_rw_q;
    reg [22:0] saved_addr_d, saved_addr_q;
    reg [31:0] saved_data_d, saved_data_q;

    reg rw_op_d, rw_op_q;

    reg [3:0] row_open_d, row_open_q;
    reg [12:0] row_addr_d[3:0], row_addr_q[3:0];

    reg [2:0] precharge_bank_d, precharge_bank_q;
    integer i;

    always @* begin
        // Default values
        dq_d = dq_q;
        dqi_d = sdram_dq;
        dq_en_d = 1'b0; // normally keep the bus in high-Z
        cle_d = cle_q;
        cmd_d = CMD_NOP; // default to NOP
        dqm_d = 1'b0;
        ba_d = 2'd0;
        a_d = 25'd0;
        state_d = state_q;
        next_state_d = next_state_q;
        delay_ctr_d = delay_ctr_q;
        addr_d = addr_q;
        data_d = data_q;
        out_valid_d = 1'b0;
        precharge_bank_d = precharge_bank_q;
        rw_op_d = rw_op_q;
        byte_ctr_d = 2'd0;

        row_open_d = row_open_q;

        // row_addr is a 2d array and must be coppied this way
        for (i = 0; i < 4; i = i + 1)
            row_addr_d[i] = row_addr_q[i];

        // The data in the SDRAM must be refreshed periodically.
        // This conter ensures that the data remains intact.
        refresh_flag_d = refresh_flag_q;
        refresh_ctr_d = refresh_ctr_q + 1'b1;
        if (refresh_ctr_q > 10'd750) begin
            refresh_ctr_d = 10'd0;
            refresh_flag_d = 1'b1;
        end

        saved_rw_d = saved_rw_q;
        saved_data_d = saved_data_q;
        saved_addr_d = saved_addr_q;
        ready_d = ready_q;

        // This is a queue of 1 for read/write operations.
        // When the queue is empty we aren't busy and can
        // accept another request.
        if (ready_q && in_valid) begin
            saved_rw_d = rw;
            saved_data_d = data_in;
            saved_addr_d = addr;
            ready_d = 1'b0;
        end

        case (state_q)
            ///// INITALIZATION /////
            INIT: begin
                ready_d = 1'b0;
                row_open_d = 4'b0;
                out_valid_d = 1'b0;
                a_d = 13'b0;
                ba_d = 2'b0;
                cle_d = 1'b1;
                state_d = WAIT;
                delay_ctr_d = 16'd10100; // wait for 101us
                next_state_d = PRECHARGE_INIT;
                dq_en_d = 1'b0;
            end
            WAIT: begin
                delay_ctr_d = delay_ctr_q - 1'b1;
                if (delay_ctr_q == 13'd0) begin
                    state_d = next_state_q;
                    if (next_state_q == WRITE) begin
                        dq_en_d = 1'b1; // enable the bus early
                        dq_d = data_q[7:0];
                    end
                end
            end
            PRECHARGE_INIT: begin
                cmd_d = CMD_PRECHARGE;
                a_d[10] = 1'b1; // all banks
                ba_d = 2'd0;
                state_d = WAIT;
                next_state_d = REFRESH_INIT_1;
                delay_ctr_d = 13'd0;
            end
            REFRESH_INIT_1: begin
                cmd_d = CMD_REFRESH;
                state_d = WAIT;
                delay_ctr_d = 13'd7;
                next_state_d = REFRESH_INIT_2;
            end
            REFRESH_INIT_2: begin
                cmd_d = CMD_REFRESH;
                state_d = WAIT;
                delay_ctr_d = 13'd7;
                next_state_d = LOAD_MODE_REG;
            end
            LOAD_MODE_REG: begin
                cmd_d = CMD_LOAD_MODE_REG;
                ba_d = 2'b0;
                // Reserved, Burst Access, Standard Op, CAS = 2, Sequential, Burst = 4
                a_d = {3'b000, 1'b0, 2'b00, 3'b010, 1'b0, 3'b010}; //010
                state_d = WAIT;
                delay_ctr_d = 13'd1;
                next_state_d = IDLE;
                refresh_flag_d = 1'b0;
                refresh_ctr_d = 10'b1;
                ready_d = 1'b1;
            end

            ///// IDLE STATE /////
            IDLE: begin
                if (refresh_flag_q) begin // we need to do a refresh
                    state_d = PRECHARGE;
                    next_state_d = REFRESH;
                    precharge_bank_d = 3'b100; // all banks
                    refresh_flag_d = 1'b0; // clear the refresh flag
                end else if (!ready_q) begin // operation waiting
                    ready_d = 1'b1; // clear the queue
                    rw_op_d = saved_rw_q; // save the values we'll need later
                    addr_d = saved_addr_q;

                    if (saved_rw_q) // Write
                        data_d = saved_data_q;

                    // if the row is open we don't have to activate it
                    if (row_open_q[saved_addr_q[9:8]]) begin
                        if (row_addr_q[saved_addr_q[9:8]] == saved_addr_q[22:10]) begin
                            // Row is already open
                            if (saved_rw_q)
                                state_d = WRITE;
                            else
                                state_d = READ;
                        end else begin
                            // A different row in the bank is open
                            state_d = PRECHARGE; // precharge open row
                            precharge_bank_d = {1'b0, saved_addr_q[9:8]};
                            next_state_d = ACTIVATE; // open current row
                        end
                    end else begin
                        // no rows open
                        state_d = ACTIVATE; // open the row
                    end
                end
            end

            ///// REFRESH /////
            REFRESH: begin
                cmd_d = CMD_REFRESH;
                state_d = WAIT;
                delay_ctr_d = 13'd6; // gotta wait 7 clocks (66ns)
                next_state_d = IDLE;
            end

            ///// ACTIVATE /////
            ACTIVATE: begin
                cmd_d = CMD_ACTIVE;
                a_d = addr_q[22:10];
                ba_d = addr_q[9:8];
                delay_ctr_d = 13'd0;
                state_d = WAIT;

                if (rw_op_q)
                    next_state_d = WRITE;
                else
                    next_state_d = READ;

                row_open_d[addr_q[9:8]] = 1'b1; // row is now open
                row_addr_d[addr_q[9:8]] = addr_q[22:10];
            end

            ///// READ /////
            READ: begin
                cmd_d = CMD_READ;
                a_d = {2'b0, 1'b0, addr_q[7:0], 2'b0};
                ba_d = addr_q[9:8];
                state_d = WAIT;
                delay_ctr_d = 13'd2; // wait for the data to show up
                next_state_d = READ_RES;

            end
            READ_RES: begin
                byte_ctr_d = byte_ctr_q + 1'b1; // we need to read in 4 bytes
                data_d = {dqi_q, data_q[31:8]}; // shift the data in
                if (byte_ctr_q == 2'd3) begin
                    out_valid_d = 1'b1;
                    state_d = IDLE;
                end
            end

            ///// WRITE /////
            WRITE: begin
                byte_ctr_d = byte_ctr_q + 1'b1; // send out 4 bytes

                if (byte_ctr_q == 2'd0) // first byte send write command
                    cmd_d = CMD_WRITE;

                dq_d = data_q[7:0];
                data_d = {8'h00, data_q[31:8]}; // shift the data out
                dq_en_d = 1'b1; // enable out bus
                a_d = {2'b0, 1'b0, addr_q[7:0], 2'b00};
                ba_d = addr_q[9:8];

                if (byte_ctr_q == 2'd3) begin
                    state_d = IDLE;
                end
            end

            ///// PRECHARGE /////
            PRECHARGE: begin
                cmd_d = CMD_PRECHARGE;
                a_d[10] = precharge_bank_q[2]; // all banks
                ba_d = precharge_bank_q[1:0];
                state_d = WAIT;
                delay_ctr_d = 13'd0;

                if (precharge_bank_q[2]) begin
                    row_open_d = 4'b0000; // closed all rows
                end else begin
                    row_open_d[precharge_bank_q[1:0]] = 1'b0; // closed one row
                end
            end

            default: state_d = INIT;
        endcase

    end

    always @(posedge clk) begin
        if(rst) begin
            cle_q <= 1'b0;
            dq_en_q <= 1'b0;
            state_q <= INIT;
            ready_q <= 1'b0;
        end else begin
            cle_q <= cle_d;
            dq_en_q <= dq_en_d;
            state_q <= state_d;
            ready_q <= ready_d;
        end

        saved_rw_q <= saved_rw_d;
        saved_data_q <= saved_data_d;
        saved_addr_q <= saved_addr_d;

        cmd_q <= cmd_d;
        dqm_q <= dqm_d;
        ba_q <= ba_d;
        a_q <= a_d;
        dq_q <= dq_d;
        dqi_q <= dqi_d;

        next_state_q <= next_state_d;
        refresh_flag_q <= refresh_flag_d;
        refresh_ctr_q <= refresh_ctr_d;
        data_q <= data_d;
        addr_q <= addr_d;
        out_valid_q <= out_valid_d;
        row_open_q <= row_open_d;
        for (i = 0; i < 4; i = i + 1)
            row_addr_q[i] <= row_addr_d[i];
        precharge_bank_q <= precharge_bank_d;
        rw_op_q <= rw_op_d;
        byte_ctr_q <= byte_ctr_d;
        delay_ctr_q <= delay_ctr_d;
    end
endmodule
