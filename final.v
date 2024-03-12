`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/07/2024 06:00:44 PM
// Design Name: 
// Module Name: datapath
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
/*
Does the state machine produce output registers that the dp can use
*/
/*
Do i make an inout to deal w bram address reading and return? or sep signals
*/

/*
Does it make sense to enable dout for bram, drive it with the same wire
that is driven with input bram_rd
*/

/*
I put in extra signal to make crossing clock domain logic fast_clk
*/

/*
memAdr = cmdreg[5:3] which is user defined element
cmdreg ----->|memAdr|----->bram_adr

output port is assigned to value of memAdr to interfacce with the block ram,
*/

module datapath(
    input clk,
    input reset,
    input [7:0] gpio_cmdreg,
    input [7:0] gpio_mult,
    input [7:0] gpio_offset,
    input [31:0] bram_rd,
    
    output [31:0] bram_adr,
    output [31:0] gpio_rd,
    output bram_en;

    );
    //datapath 
    //states 
    parameter idle = 3'b100;
    parameter decode = 3'b000;
    parameter memory = 3'b001;
    parameter execute = 3'b010;
    parameter stall = 3'b011;
    
    //FSM output registers and flags
    reg [31:0] memAdr;
    reg [1:0] operation;
    reg adrReadyFlag;
    reg opReadyFlag;
    //reg readyBit;
    
    //FSM registers
    reg [2:0] state_current, state_next;
    
    //bram to datapath register
    reg [31:0] data;
    
    //CDC registers
    reg [7:0] cmdreg_init;
    reg [7:0] cmdreg_metastable;
    reg [7:0] cmdreg_stable;
    
    
    reg [31:0] gpio_rd_init;
    reg [31:0] gpio_rd_metastable;
    reg [31:0] gpio_rd_stable;
    
    //continous assignments
    assign bram_adr = memAdr;
    assign bram_rd = data;
    assign gpio_rd = gpio_rd_init;
    assign gpio_cmdreg = cmdreg_init;

    //CDC synchronizer for GPIO_RD
    always @(posedge clk) begin
        if(reset) begin
            gpio_rd_metastable <= 32'd0;
            gpio_rd_stable <= 32'd0;
        end begin
            gpio_rd_metastable <= gpio_rd_init;
            gpio_rd_stable <= gpio_rd_metastable;
        end
    end

    //CDC syncrhonizer for cmdreg
    always @(posedge clk) begin
        if(reset) begin
            cmdreg_metastable <= 32'd0;
            cmdreg_stable <= 32'd0;
        end else begin
            cmdreg_metastable <= cmdreg_init;
            cmdreg_stable <= cmdreg_metastable;
        end
    end
    
    //datapath / FSM control
    always @* begin
        if(~reset) begin
            operation = 2'd0;
            memAdr = 32'd0;
            adrReadyFlag = 1'b0;
            opReadyFlag = 1'b0;
            state_next = idle;
        end else begin
            case(state_current)
            
            idle: begin
                //new instruction if in this stage and cmdreg_stable[0] == 1
                if(cmdreg_stable[0]) begin
                    state_next = decode;
                end else begin
                    state_next = idle;
                end
            end

            decode: begin
                //get and store memory address and operation
                if(cmdreg_stable[5:3] == 3'b000) begin
                    memAdr = 8'h0;
                    adrReadyFlag = 1'b1;
                end else if(cmdreg_stable[5:3] == 3'b001) begin
                    memAdr = 8'h4;
                    adrReadyFlag = 1'b1;
                end else if(cmdreg_stable[5:3] == 3'b010) begin
                    memAdr = 8'h8;
                    adrReadyFlag = 1'b1;
                end else if(cmdreg_stable[5:3] == 3'b011) begin
                    memAdr = 8'h12;
                    adrReadyFlag = 1'b1;
                end else if(cmdreg_stable[5:3] == 3'b100) begin
                    memAdr = 8'h16;
                    adrReadyFlag = 1'b1;
                end else if(cmdreg_stable[5:3] == 3'b101) begin
                    memAdr = 8'h20;
                    adrReadyFlag = 1'b1;
                end else if(cmdreg_stable[5:3] == 3'b110) begin
                    memAdr = 8'h24;
                    adrReadyFlag = 1'b1;
                end else if(cmdreg_stable[5:3] == 3'b111) begin
                    memAdr = 8'h28;
                    adrReadyFlag = 1'b1;
                end else begin
                    state_next = stall; //since none of the memory locations coincide but cmdreg[0] = 1, just stall until its 0. 
                end

                if(cmdreg_stable[7:6] == 2'b00) begin //read
                    operation = 2'b00;
                    opReadyFlag = 1'b1;
                end else if(cmdreg_stable[7:6] == 2'b01) begin //compliment
                    operation = 2'b01;
                    opReadyFlag = 1'b1;
                end else if(cmdreg_stable[7:6] == 2'b10) begin //offset
                    operation = 2'b10;
                    opReadyFlag = 1'b1;
                end else if(cmdreg_stable[7:6] == 2'b11) begin //multiplication
                    operation = 2'b11;
                    opReadyFlag = 1'b1;
                end else begin
                    state_next = stall; //same as before
                end

                if(opReadyFlag == 1 && adrReadyFlag == 1) begin
                    state_next = memory;
                end else begin
                    state_next = stall; //should never reach this stage
                end
            end                   
        
            // I can probably combine decode and memory into 1 stage if i set bram_en to 1 at the beginnning of decode
            memory: begin // I can manipulate enable signal here, I can set it to an output wire which restricts enable of bram so it can only be used in this state
                bram_en = 1'b1;
            end
            endcase
        end
    end
    
    //datapath for calculations
    always @* begin
        if(reset) begin
            memAdr = 32'b0;
        end else begin
            if(memAdr == 0) begin
                memAdr = 8'h0;
            end else if(memAdr == 1) begin
                memAdr = 8'h4;
            end else if(memAdr == 2) begin
                memAdr = 8'h8;
            end else if(memAdr == 3) begin
                memAdr = 8'h12;
            end else if(memAdr == 4) begin
                memAdr = 8'h16;
            end else if(memAdr == 5) begin
                memAdr = 8'h20;
            end else if(memAdr == 6) begin
                memAdr = 8'h24;
            end else if(memAdr == 7) begin
                memAdr = 8'h28;
            end
            
            //may have done this wrong because calulation should be done before it goes
            if(operation == 0) begin //read
                gpio_rd_reg = data;
            end else if(operation == 1) begin //compliment
                gpio_rd_stable = ~gpio_rd_stable;
            end else if(operation == 2) begin //offset
                gpio_rd_stable = gpio_rd_stable + offset_stable;
            end else if(operation == 3) begin
                gpio_rd_stable = gpio_rd_stable * mult_stable;
            end
        end
    end
    
    always @(posedge clk) begin
        if(reset) begin
            state_current <= idle;
        end else begin
            state_current <= state_next;
        end
    end
    
    //create a wire that tells FSM to do something
    
    //instantiate both GPIO's
    
    //instantiate block ram to be able to read from it given FSM
    
endmodule
