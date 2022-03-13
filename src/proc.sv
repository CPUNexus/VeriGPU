// represents processor
module proc(
    input rst, clk,

    output reg [data_width - 1:0] out,
    // output reg [31:0] out,
    output reg outen,
    output reg outflen,

    output reg [6:0] c2_op,
    output reg [2:0] c2_funct,
    output reg [4:0] c2_rd_sel,
    output reg [4:0] c2_rs1_sel,
    output reg [4:0] c2_rs2_sel,
    output reg [6:0] c2_imm1,
    output [31:0] c2_x1,

    output reg [addr_width - 1:0] pc,
    output reg [4:0] state,

    output reg [addr_width - 1:0] mem_addr,
    input [data_width - 1:0] mem_rd_data,
    output reg [data_width - 1:0] mem_wr_data,
    output reg mem_wr_req,
    output reg mem_rd_req,
    input mem_ack,
    input mem_busy,

    output reg halt
);
    // reg [31:0] regs[32];
    reg [31:0] c2_instr;
    typedef enum bit[4:0] {
        C1,
        C2
    } e_state;

    wire [6:0] c1_op;
    wire [2:0] c1_funct3;
    wire [9:0] c1_op_funct;
    wire [4:0] c1_rd_sel;
    wire [4:0] c1_rs1_sel;
    wire [4:0] c1_rs2_sel;
    wire [6:0] c1_imm1;

    wire signed [addr_width - 1:0] c1_store_offset;
    wire signed [addr_width - 1:0] c1_load_offset;
    wire signed [31:0] c1_i_imm;
    wire signed [addr_width - 1:0] c1_branch_offset;
    wire [31:0] c1_instr;

    wire [data_width - 1:0] rf_rs1_data;
    wire [data_width - 1:0] rf_rs2_data;

    wire rf_wr_req;
    // reg rf_ack;
    wire [reg_sel_width - 1:0] rf_rd_sel;
    wire [data_width - 1:0] rf_rd_data;

    // we are going to assume that only processor writes to 
    // the registry file, no apu writer etc; therefore
    // our writes always succee
    reg_file reg_file_(
        .clk(clk), .rst(rst),

        .proc_rs1_sel(c1_rs1_sel),
        .proc_rs2_sel(c1_rs2_sel),
        .proc_rs1_data(rf_rs1_data),
        .proc_rs2_data(rf_rs2_data),

        .proc_wr_req(rf_wr_req),
        // .proc_ack(rf_ack),
        .proc_rd_sel(rf_rd_sel),
        .proc_rd_data(rf_rd_data)
    );

    reg [reg_sel_width - 1:0] reg_wr_load_sel;
    reg [data_width - 1:0] reg_wr_load_data;
    reg reg_wr_load_req;
    wire reg_wr_load_ack;

    reg [reg_sel_width - 1:0] reg_wr_addi_sel;
    reg [data_width - 1:0] reg_wr_addi_data;
    reg reg_wr_addi_req;
    wire reg_wr_addi_ack;

    // wire [reg_sel_width - 1:0] rf_wr_reg_sel;
    // wire [data_width - 1:0] rf_wr_data;
    // wire rf_wr_req;

    proc_reg_wr_mux2 proc_reg_wr_mux2_(
        .clk(clk),

        .reg_sel0(reg_wr_load_sel),
        .data0(reg_wr_load_data),
        .req0(reg_wr_load_req),
        .ack0(reg_wr_load_ack),

        .reg_sel1(reg_wr_addi_sel),
        .data1(reg_wr_addi_data),
        .req1(reg_wr_addi_req),
        .ack1(reg_wr_addi_ack),

        .rf_wr_req(rf_wr_req),
        .rf_wr_reg_sel(rf_rd_sel),
        .rf_wr_data(rf_rd_data)
    );

    task read_next_instr(input [addr_width - 1:0] instr_addr);
        mem_addr <= instr_addr;
        mem_rd_req <= 1;
        state <= C1;
        pc <= instr_addr;
        // regs[0] <= '0;
    endtask

    task write_out(input [data_width - 1:0] _out);
        out <= _out;
        outen <= 1;
    endtask

    task write_float(input [data_width - 1:0] _out);
        out <= _out;
        outflen <= 1;
    endtask

    task op_imm(input [2:0] _funct, input [4:0] _rd_sel, input [31:0] _rs1_data, input [31:0] _i_imm);
        case(_funct)
            ADDI: begin
                // regs[_rd] <= regs[_rs1] + _i_imm;
                reg_wr_addi_req <= 1;
                reg_wr_addi_sel <= _rd_sel;
                reg_wr_addi_data <= _rs1_data + _i_imm;
                read_next_instr(pc + 4);
            end
            default: begin
            end
        endcase
    endtask

    // task op_branch(input [2:0] _funct, input [4:0] _rs1, input [4:0] _rs2, input [addr_width - 1:0] _offset);
    //     reg branch;
    //     branch = 0;
    //     case(_funct)
    //         BEQ: begin
    //             if (regs[_rs1] == regs[_rs2]) begin
    //                 branch = 1;
    //             end
    //         end
    //         BNE: begin
    //             if (regs[_rs1] != regs[_rs2]) begin
    //                 branch = 1;
    //             end
    //         end
    //         default: begin
    //         end
    //     endcase

    //     if (branch) begin
    //         read_next_instr(pc + {_offset[30:0], 1'b0});
    //     end else begin
    //         read_next_instr(pc + 4);
    //     end
    // endtask

    // task op_op(input [9:0] _funct, input [4:0] _rd, input [4:0] _rs1, input [4:0] _rs2);
    //     case(_funct)
    //         ADD: begin
    //             regs[_rd] <= regs[_rs1] + regs[_rs2];
    //         end
    //         SLT: begin
    //             // this is actually unsigned. Need to fix...
    //             regs[_rd] <= regs[_rs1] < regs[_rs2] ? '1 : '0;
    //         end
    //         SLTU: begin
    //             regs[_rd] <= regs[_rs1] < regs[_rs2] ? '1 : '0;
    //         end
    //         AND: begin
    //             regs[_rd] <= regs[_rs1] & regs[_rs2];
    //         end
    //         OR: begin
    //             regs[_rd] <= regs[_rs1] | regs[_rs2];
    //         end
    //         XOR: begin
    //             regs[_rd] <= regs[_rs1] ^ regs[_rs2];
    //         end
    //         SLL: begin
    //             regs[_rd] <= regs[_rs1] << regs[_rs2][4:0];
    //         end
    //         SRL: begin
    //             regs[_rd] <= regs[_rs1] >> regs[_rs2][4:0];
    //         end
    //         SUB: begin
    //             regs[_rd] <= regs[_rs1] - regs[_rs2];
    //         end
    //         SRA: begin
    //             // not sure what an 'arithmetic' shift is
    //             // need to fix...
    //             regs[_rd] <= regs[_rs1] >> regs[_rs2][4:0];
    //         end

    //         // RV32M
    //         MUL: begin
    //             regs[_rd] <= regs[_rs1] * regs[_rs2];
    //         end
    //         REM: begin
    //         end

    //         default: begin
    //         end
    //     endcase
    //     read_next_instr(pc + 4);
    // endtask

    // task op_lui(input [31:0] _instr, input [4:0] _rd);
    //     regs[_rd] <= {_instr[31:12], {12{1'b0}} };
    //     read_next_instr(pc + 4);
    // endtask

    // task op_auipc(input [31:0] _instr, input [4:0] _rd);
    //     regs[_rd] <= {_instr[31:12], {12{1'b0}}} + pc;
    //     read_next_instr(pc + 4);
    // endtask

    task op_store(input [addr_width - 1:0] _addr);
        case (_addr)
            1000: begin
                write_out(rf_rs2_data);
                read_next_instr(pc + 4);
            end
            1004: begin
                halt <= 1;
            end
            1008: begin
                write_float(rf_rs2_data);
                read_next_instr(pc + 4);
            end
            default: begin
                mem_addr <= (rf_rs1_data + c1_store_offset);
                mem_wr_req <= 1;
                mem_wr_data <= rf_rs2_data;
                state <= C2;
            end
        endcase
    endtask

    task instr_c1();
        case (c1_op)
            OPIMM: begin
                op_imm(c1_funct3, c1_rd_sel, rf_rs1_data, c1_i_imm);
            end
            LOAD: begin
                // read from memory
                // lw rd, offset(rs1)
                mem_addr <= (rf_rs1_data + c1_load_offset);
                mem_rd_req <= 1;
                state <= C2;
            end
            STORE: begin
                // write to memory
                // sw rs2, offset(rs1)
                op_store(rf_rs1_data + c1_store_offset);
            end
            // BRANCH: begin
            //     // e.g. beq rs1, rs2, offset
            //     op_branch(c1_funct3, c1_rs1, c1_rs2, c1_branch_offset);
            // end
            // OP: begin
            //     op_op(c1_op_funct, c1_rd, c1_rs1, c1_rs2);
            // end
            // LUI: begin
            //     op_lui(c1_instr, c1_rd);
            // end
            // AUIPC: begin
            //     op_auipc(c1_instr, c1_rd);
            // end
            default: begin
                halt <= 1;
            end
        endcase
    endtask

    task instr_c2();
        case (c2_op)
            LOAD: begin
                if(mem_ack) begin
                    // regs[rd] <= mem_rd_data;
                    reg_wr_load_req <= 1;
                    reg_wr_load_sel <= c2_rd_sel;
                    reg_wr_load_data <= mem_rd_data;
                    read_next_instr(pc + 4);
                end
            end
            STORE: begin
                if(mem_ack) begin
                    read_next_instr(pc + 4);
                end
            end
            default: begin
            end
        endcase
    endtask

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            halt <= 0;
            outen <= 0;
            outflen <= 0;
            read_next_instr(0);
        end
        else begin
            mem_rd_req <= 0;
            mem_wr_req <= 0;
            outen <= 0;
            outflen <= 0;
            case(state)
                C1: begin
                    mem_rd_req <= 0;
                    if(mem_ack) begin
                        instr_c1();
                        c2_instr <= mem_rd_data;
                        c2_op <= mem_rd_data[6:0];
                        c2_funct <= mem_rd_data[14:12];
                        c2_rd_sel <= mem_rd_data[11:7];
                        c2_rs1_sel <= mem_rd_data[19:15];
                        c2_rs2_sel <= mem_rd_data[24:20];
                        c2_imm1 <= mem_rd_data[31:25];
                    end
                end
                C2: begin
                    instr_c2();
                end
                default: halt <= 1;
            endcase
        end
    end
    assign c1_op = mem_rd_data[6:0];
    assign c1_rd_sel = mem_rd_data[11:7];
    assign c1_rs1_sel = mem_rd_data[19:15];
    assign c1_rs2_sel = mem_rd_data[24:20];
    assign c1_funct3 = mem_rd_data[14:12];
    assign c1_imm1 = mem_rd_data[31:25];
    assign c1_instr = mem_rd_data;
    assign c1_store_offset = {{20{mem_rd_data[31]}}, mem_rd_data[31:25], mem_rd_data[11:7]};
    assign c1_load_offset = {{20{mem_rd_data[31]}}, mem_rd_data[31:20]};
    assign c1_i_imm = {{20{mem_rd_data[31]}}, mem_rd_data[31:20]};
    assign c1_branch_offset = {{20{mem_rd_data[31]}}, mem_rd_data[31], mem_rd_data[7], mem_rd_data[30:25], mem_rd_data[11:8]};
    assign c1_op_funct = {mem_rd_data[31:25], mem_rd_data[14:12]};
    // assign x1 = regs[1];
endmodule
