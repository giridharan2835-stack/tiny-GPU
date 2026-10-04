module gpu_top #(parameter N_CORES = 4) (

    input clk,
    input rst,

    input start,

    input [7:0] thread_count,

    // Instruction memory
    input [15:0] prog_mem [0:255],

    output done
);

    // ============================================================
    // DISPATCH SIGNALS
    // ============================================================

    wire [N_CORES-1:0] core_enable;

    wire [N_CORES-1:0] thread_start;

    wire [N_CORES-1:0] core_done;

    wire [7:0] thread_id [0:N_CORES-1];

    // ============================================================
    // INSTRUCTION SIGNALS
    // ============================================================

    wire [7:0] instr_addr [0:N_CORES-1];

    wire [15:0] instruction [0:N_CORES-1];

    // ============================================================
    // MEMORY SIGNALS
    // ============================================================

    wire [N_CORES-1:0] mem_req;

    wire [N_CORES-1:0] mem_wr_en;

    wire [7:0] mem_addr [0:N_CORES-1];

    wire [7:0] mem_wr_data [0:N_CORES-1];

    wire [7:0] mem_rd_data [0:N_CORES-1];

    wire [N_CORES-1:0] mem_ready;

    // Packed buses for memory controller
    wire [N_CORES*8-1:0] mem_addr_bus;

    wire [N_CORES*8-1:0] mem_wr_data_bus;

    wire [N_CORES*8-1:0] mem_rd_data_bus;

    // ============================================================
    // SHARED DATA MEMORY
    // ============================================================

    reg [7:0] data_mem [0:255];

    // Memory-controller output
    wire       mem_we;
    wire [7:0] mem_write_addr;
    wire [7:0] mem_write_data;

    // ============================================================
    // DISPATCH UNIT
    // ============================================================

    dispatch_unit #(.N_CORES(N_CORES)) dispatcher (

        .clk          (clk),
        .rst          (rst),

        .start        (start),

        .thread_count (thread_count),

        .core_done    (core_done),

        .core_enable  (core_enable),

        .thread_start (thread_start),

        .thread_id    (thread_id),

        .done         (done)

    );

    // ============================================================
    // SHADER CORES
    // ============================================================

    genvar i;

    generate

        for (i = 0; i < N_CORES; i = i + 1) begin : core_gen

            // Instruction memory read
            assign instruction[i] = prog_mem[instr_addr[i]];

            // Pack memory signals
            assign mem_addr_bus[i*8 +: 8] =
                mem_addr[i];

            assign mem_wr_data_bus[i*8 +: 8] =
                mem_wr_data[i];

            // Unpack read data
            assign mem_rd_data[i] =
                mem_rd_data_bus[i*8 +: 8];


            // ------------------------------------------
            // SHADER CORE
            // ------------------------------------------

            shader_core #(.CORE_ID(i)) core_inst (

                .clk          (clk),
                .rst          (rst),

                .enable       (core_enable[i]),

                .thread_start (thread_start[i]),

                .thread_id    (thread_id[i]),

                // Instruction interface
                .instruction  (instruction[i]),

                .instr_addr   (instr_addr[i]),

                // Memory interface
                .mem_data_in  (mem_rd_data[i]),

                .mem_ready    (mem_ready[i]),

                .mem_read_en  (mem_req[i]),

                .mem_write_en (mem_wr_en[i]),

                .mem_addr     (mem_addr[i]),

                .mem_data_out (mem_wr_data[i]),

                .done         (core_done[i])

            );

        end

    endgenerate

    // ============================================================
    // SHARED MEMORY CONTROLLER
    // ============================================================

    mem_ctrl #(.N_CORES(N_CORES)) memory_controller (

        .clk         (clk),
        .rst         (rst),

        .req         (mem_req),

        .wr_en       (mem_wr_en),

        .addr_bus    (mem_addr_bus),

        .wr_data_bus (mem_wr_data_bus),

        .mem         (data_mem),

        .rd_data_bus (mem_rd_data_bus),

        .ready       (mem_ready),

        .mem_we      (mem_we),

        .mem_addr    (mem_write_addr),

        .mem_wdata   (mem_write_data)

    );

    // ============================================================
    // ACTUAL MEMORY WRITE
    // ============================================================

    always @(posedge clk) begin

        if (mem_we)
            data_mem[mem_write_addr] <= mem_write_data;

    end

endmodule
