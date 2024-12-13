
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Paige Larson
// 
// Create Date: 11/25/2024 01:54:11 AM
// Design Name: 
// Module Name: reorder_buffer
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 1ps


module reorder_buffer(
    
    input               clk, 
    //input [31:0]        PC,
    input               rstn,

    input [5:0]         old_dest_reg_0,       //from rename      
    input [5:0]         dest_reg_0,           //from rename
    input [31:0]        dest_data_0,          //from rename    
    input               store_add_0,          //from rename
    input               store_data_0,         //from rename
    input               instr_PC_0,            //from rename    

    input [31:0]        complete_pc_0,
    input [31:0]        complete_pc_1,
    input [31:0]        complete_pc_2,
    input [31:0]        complete_pc_3,
    
    input [31:0]        new_dr_data_0,
    input [31:0]        new_dr_data_1,
    input [31:0]        new_dr_data_2,
    input [31:0]        new_dr_data_3,
    
    input is_dispatching,
    input is_store,
    input [5:0] set_invalid_from_UIQ,

    output reg [63:0]    retire;
    output reg [5:0]    out_add_1,
    output reg [31:0]   out_data_1,
    output reg [31:0]   out_pc_1,

    output reg [5:0]    out_add_2,
    output reg [31:0]   out_data_2,
    output reg [31:0]   out_pc_2,
    output reg [1:0]    stall,
    output [63:0] ready,

    output reg [5:0]    reg_update_ARF_1,
    output reg [5:0]    reg_update_ARF_2,
    output reg [31:0]   value_update_ARF_1,
    output reg [31:0]   value_update_ARF_2,

    output reg [5:0]    old_reg_1,
    output reg [5:0]    old_reg_2,

    output reg          src1_ready_flag,     
    output reg          src2_ready_flag,
    output reg [5:0]    sr1_reg_ready,   
    output reg [5:0]    sr2_reg_ready,
    output reg [31:0]   sr1_value_ready,
    output reg [31:0]   sr2_value_ready,

    output reg [31:0]   pc_retire_1,
    output reg [31:0]   pc_retire_2



    
    );

    // 1. multiple entries per cycle
    // 2. ROB_reg_ready determination
    // 3. signals like "complete", how to update
    
    //cases in which ROB needs to update:
    //  1: we add one item into the ROB, mark as 1 in retire (dispatch stage) 
    //  2: we add more than one item into the ROB (dispatch stage)
    //  3: update complete when complete, set 0 in retire (complete stage)
    //  4: remove entire line from ROB (retire)
    
    //general plan
        //whenever anything is renamed (2 at a time max) add a row in ROB
        
        //when an instr leaves ALU, we send its info back and check its cpu. Match it with its ROB row, set complete to 1, update data, and set retire at the dr to 0
        
        //go through ROB, starting from top, if complete=1 and all prior lines are retired, set reg is ready to 1

    reg [6:0]  retire_head;
    reg [6:0]  new_head;



    reg [31:0] ROB [63:0] [7:0];
    reg [31:0] new_dr_data [3:0];
    reg [31:0] complete_pc [3:0];

    // insert into ROB
    integer i;
    integer j;
    integer k;
    integer max_retire=0;
    integer vals;
    
    always @(posedge clk or negedge rstn) begin
        //reset ROB
        if (~rstn)begin
            for (i = 0; i < 64; i = i + 1) begin
                ROB[i][0] = 1'b0;    // whether or not slot is taken
                ROB[i][1] = 0;       // dest reg
                ROB[i][2] = 0;       // old dest reg
                ROB[i][3] = 0;       // current dest reg data
                ROB[i][4] = 0;       // store address in sw
                ROB[i][5] = 0;       // store imm val
                ROB[i][6] = 0;       // instr pc
                ROB[i][7] = 0;       // complete
                
                retire[i]=1'b0;      //return buffer
                ready[i]=1'b1;

                retire_head = 'b0;
                new_head= 'b0;
                reg_update_ARF_1= 6'b0;
                reg_update_ARF_2= 6'b0;
                value_update_ARF_1= 32'b0;
                value_update_ARF_2= 32'b0;
                old_reg_1= 6'b0;
                old_reg_2= 6'b0;

                sr1_reg_ready= 6'b0;
                sr2_reg_ready= 6'b0;
                sr1_value_ready= 32'b0;
                sr2_value_ready= 32'b0;

                pc_retire_1= 32'b0;
                pc_retire_2= 32'b0;
            end  
        end            
        else begin

            for (i = 0; i < 64; i = i + 1) begin
                R_retire[i]=1'b0;      // initialize retire buffer every cycle
            end

            //adding something new to rob
            if(is_dispatching) begin //place first new instr
                if (ROB[new_head][0] == 1'b0) begin
                    ROB[new_head][0] = 1'b1;           //valid
                    ROB[new_head][1] = dest_reg_0;     //dr
                    ROB[new_head][2] = old_dest_reg_0; //old dr
                    ROB[new_head][3] = dest_data_0;    //data at dr
                    ROB[new_head][4] = store_add_0;    //store address
                    ROB[new_head][5] = store_data_0;   //store data
                    ROB[new_head][6] = instr_PC_0;     //instr pc
                    ROB[new_head][7] = 1'b0;           //complete
                    
                    new_head=new_head+1
                     
                end
                else if(i==64) begin
                    stall=1'b1;
                end
            end    
        end
    end

    
    always @(*) begin

        //set up complete and data arrays
        new_dr_data[0] = new_dr_data_0;
        new_dr_data[1] = new_dr_data_1;
        new_dr_data[2] = new_dr_data_2;
        new_dr_data[3] = new_dr_data_3;
        
        complete_pc[0] = complete_pc_0;
        complete_pc[1] = complete_pc_1;
        complete_pc[2] = complete_pc_2;
        complete_pc[3] = complete_pc_3;

        //complete and update data
        for(k=0; k<64; k=k+1)begin
            if(ROB[i][0]==1'b1) begin
                for (i = 0; i < 4; i = i + 1) begin
                    if(ROB[k][6]==complete_pc[i] && ROB[k][0]==1'b1)begin
                        ROB[k][7]=1'b1;             //set to complete
                        ROB[k][3]=new_dr_data[k];   // update data
                    end
                end
            end
        end


        //free retire if in order
        //if row is first populated row, check if complete
            //if complete, retire rob row and dr in retire buffer
                //see if next populated row is complete
                    //if so, retire that row too
                    //if not, exit 
            //if not complete, exit

        //ARF Write Back
        reg_update_ARF_1    = 6'b0;
        reg_update_ARF_2    = 6'b0;
        value_update_ARF_1  = 32'b0;
        value_update_ARF_2  = 32'b0;
        src1_ready_flag = 1'b0;
        src2_ready_flag = 1'b0;

        max_retire=0;
        for (i = 0; i < 2; i = i + 1) begin //check to retire
            if (ROB[retire_head][0] == 1'b1) begin
                if(ROB[retire_head][7]==1'b1 && max_retire==0)begin
                    //retire in ROB and retire buffer 
                    ready[ROB[retire_head][1]]=1'b1;
                    retire[ROB[retire_head][2]]=1'b1; 

                    ROB[retire_head][0] = 1'b0;           //valid
                    ROB[retire_head][1] = 0;     //dr
                    ROB[retire_head][2] = 0; //old dr
                    ROB[retire_head][3] = 0;    //data at dr
                    ROB[retire_head][4] = 0;    //store address
                    ROB[retire_head][5] = 0;   //store data
                    ROB[retire_head][6] = 0;     //instr pc
                    ROB[retire_head][7] = 1'b0;           //complete
                            
                    max_retire=0;

                    if (~is_store) begin
                        reg_update_ARF_1 = ROB[retire_head][1];
                        value_update_ARF_1 = ROB[retire_head][3];
                        old_reg_1= ROB[retire_head][2];
                        src1_ready_flag= 1'b1;
                    end

                    retire_head = retire_head + 1;
                    if(retire_head > 63)begin
                        retire_head = 0;
                    end
                end          
            end

            if (ROB[retire_head][0] == 1'b1) begin
                if(ROB[retire_head][7]==1'b1 && max_retire==1)begin
                    //retire in ROB and retire buffer 
                    ready[ROB[retire_head][1]]=1'b1;
                    retire[ROB[retire_head][2]]=1'b1; 

                    ROB[retire_head][0] = 1'b0;           //valid
                    ROB[retire_head][1] = 0;     //dr
                    ROB[retire_head][2] = 0; //old dr
                    ROB[retire_head][3] = 0;    //data at dr
                    ROB[retire_head][4] = 0;    //store address
                    ROB[retire_head][5] = 0;   //store data
                    ROB[retire_head][6] = 0;     //instr pc
                    ROB[retire_head][7] = 1'b0;           //complete
                            
                    max_retire=0;

                    if (~is_store) begin
                        reg_update_ARF_1 = ROB[retire_head][1];
                        value_update_ARF_1 = ROB[retire_head][3];
                        old_reg_1= ROB[retire_head][2];
                        src1_ready_flag= 1'b1;
                    end

                    retire_head = retire_head + 1;
                    if(retire_head > 63)begin
                        retire_head = 0;
                    end
                end          
            end

        end

        if (src1_ready_flag) begin
            src1_reg_ready   = reg_update_ARF_1;
            src1_value_ready  = value_update_ARF_1;
        end
        if (src2_ready_flag) begin
            src2_reg_ready   = reg_update_ARF_2;
            src2_value_ready  = value_update_ARF_2;


    end

endmodule