module decode(
    //Input
    instr,
    
    //Output: Source registers, destination registers, ALUOP, LW/SW Flag, Control Signals 
    opcode,
    srcReg1, // Src registers
    srcReg2,
    imm, 
    lwSw, // Lw/sw flags 
    aluOp, // Control signals 
    regWrite,
    aluSrc,
    branch,
    memRead,
    memWrite,
    memToReg
);
    // COMPONENTS: 
    // 1. Extract Opcode, funct3, funct7 (distinguish instruction)
    // 2. Determine registers and control signals 
    // 3. Immediate Generator 

    input [31:0] instr;
    
    output reg [6:0] opcode;
    output reg [5:0] srcReg1;
    output reg [5:0] srcReg2;
    output reg [31:0] imm; 
    output reg [1:0] lwSw;
    output reg [1:0] aluOp; 
    output reg regWrite;
    output reg aluSrc;
    output reg branch;
    output reg memRead;
    output reg memWrite;
    output reg memToReg


    reg [5:0] controlSignals;
    controller contMod (
        .instr(instr),
        .controlSignals(controlSignals),
        .aluOp(aluOp),
        .lwSw(lwSw)
    );


endmodule

module controller(
    instr,
    controlSignals,
    aluOp,
    lwSw
);
    input [31:0] instr;

    output reg [5:0] controlSignals;
    output reg [1:0] aluOp;
    output reg [1:0] lwSw;

    reg [6:0] opcode;
    always @(*) begin
        opcode = instr[6:0];
        if (opcode == 7b'0110011) begin // R-type instruction
            controlSignals = 6b'100000;
            aluOp = 2b'10;
            lwSw = 2b'00;
        end else if (opcode == 7b'0010011) begin // I-type instruction
            controlSignals = 6b'110000;
            aluOp = 2b'10;
            lwSw = 2b'00;
        end else if (opcode == 7b'0000011) begin // Load instruction
            controlSignals = 6b'110101;
            aluOp = 2b'00;
            lwSw = 2b'10;
        end else if (opcode == 7b'0100011) begin // Store instruction
            controlSignals = 6b'010010;
            aluOp = 2b'00;
            lwSw = 2b'01;
        end else if (opcode == 7b'1100011) begin // Branch-type instruction
            controlSignals = 6b'001000;
            aluOp = 2b'01;
            lwSw = 2b'00;
        end else begin
            controlSignals = 6b'000000;
            aluOp = 2b'00;
            lwSw = 2b'00;
        end
    end
endmodule





