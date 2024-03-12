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
    input fast_clk,
    input reset,
    //once I create the wrapper will vivado instantiate these input wires with the same name wires in block diagram
    input [7:0] gpio_cmdreg,
    input [7:0] gpio_mult,
    input [7:0] gpio_offset,
    //should this be an inout? output the address, input the data read so assign the inout wire to a mux in verilog
    input [31:0] bram_rd,
    //This is returned when the datapath gives the output bram_address to the block ram and gets the 32 bit value back
    //input wire [31:0] bram_data,
    
    output [31:0] bram_adr,
    output [31:0] gpio_rd
    
    
    //I want to write my CMDREG[5:3] signal to the BRAM and read so is an ouput wire correct? will wrapper recognize this
    //output wire bramaddress;
    );
    //datapath 
    //states 
    parameter idle = 3'b100;
    parameter read = 3'b000;
    parameter compliment = 3'b001;
    parameter offset = 3'b010;
    parameter mult = 3'b011;
    
    //FSM output registers
    reg [31:0] memAdr;
    reg [1:0] operation;
    reg readyBit;
    
    //FSM to datapath output wire 
    wire [1:0] operationFSM;
    
    //FSM t o datapath wires wires
    //assign bram_address = memAdr;
    assign operationFSM = operation;
    
    //FSM registers, do I need these since there is no state next?
    reg [2:0] state_current, state_next;
    
    //bram to datapath register
    reg [31:0] data;
    
    //crossing clock domain registers
    reg [2:0] CDC_counter;
    
    wire [7:0] cmdreg_stretch;
    reg [7:0] cmdreg_metastable;
    reg [7:0] cmdreg_stable;
    
    wire [7:0] mult_stretch;
    reg [7:0] mult_metastable;
    reg [7:0] mult_stable;
    
    wire [7:0] offset_stretch;
    reg [7:0] offset_metastable;
    reg [7:0] offset_stable;
    
    //slow to fast
    reg [31:0] gpio_rd_reg;
    reg [31:0] gpio_rd_metastable;
    reg [31:0] gpio_rd_stable;
    
    //crossing clock domain 
    //datapath assignments
    //memAdr register that is from FSM will be assigned to datapath output wire bram_adr which will connect to BRAM to get data
    // should this be assigned elsewhere after dp always block?
    assign bram_adr = memAdr;
    //input bram_rd which is the data from bram_adr is assigned to data register to be executed
    assign bram_rd = data;
    
    assign gpio_rd = gpio_rd_reg;
    
    //STILL NEED TO DOUBLE FLOP GPIO_RD
    //slow to fast
    always @(posedge fast_clk) begin
        if(reset) begin
            gpio_rd_metastable <= 32'b0;
            gpio_rd_stable <= 32'b0;
        end else begin
            gpio_rd_metastable <= gpio_rd_reg;
            gpio_rd_stable <= gpio_rd_metastable;
        end
    end 
    
    //on posedge of fast_clk count 4 clock cycles
    always @(posedge fast_clk) begin
        if(reset) begin
            CDC_counter <= 3'b0;
        end else begin
            if(gpio_cmdreg[0] == 1'b1) begin
                CDC_counter <= 3'b100;
            end
            if(CDC_counter > 0) begin
                CDC_counter <= CDC_counter - 1;
            end
        end
    end
    
    assign cmdreg_stretch = (CDC_counter > 0) ? gpio_cmdreg : 0;
    assign mult_stretch = (CDC_counter > 0) ? gpio_mult : 0;
    assign offset_stretch = (CDC_counter > 0) ? gpio_offset :0;
    
    //datapath 75 Mhz clk
    always @(posedge clk) begin
        if(reset) begin
            cmdreg_metastable <= 0;
            cmdreg_stable <= 0;
            mult_metastable <= 0;
            mult_stable <= 0;
            offset_metastable <= 0;
            offset_stable <= 0;
        end else begin
            cmdreg_metastable <= cmdreg_stretch;
            cmdreg_stable <= cmdreg_metastable;  
            
            mult_metastable <= mult_stretch;
            mult_stable <= mult_metastable;
            
            offset_metastable <= offset_stretch;
            offset_stable <= offset_metastable;
        end  
    end
    
    //FSM
    //how do i signify when to use FSM
    always @* begin
        if(~reset) begin
            memAdr = 32'b000;
            operation = 2'b00;
            readyBit = 1'b0;
            state_next = idle;
        end else begin
            case(state_current)
            
            idle: begin
                if(cmdreg_stable[0]) begin
                //set condition here for rising edge of pulse
                    if(cmdreg_stable[7:6] == read) begin
                        state_next = read;
                    end else if (cmdreg_stable[7:6] == compliment) begin
                        state_next = compliment;
                    end else if (cmdreg_stable[7:6] == offset) begin
                        state_next = offset;
                    end else if (cmdreg_stable[7:6] == mult) begin
                        state_next = mult;
                    end 
                end else begin
                    state_next = idle;
                end
            end
                       
            read: begin
                //disable the multiply and offset gpio?
                memAdr = cmdreg_stable[5:3];
                operation = cmdreg_stable[7:6];
                readyBit = cmdreg_stable[0];
                //do i have to do this
                cmdreg_stable[0] = 1'b0;
                state_next = idle;                   
            end
            
            compliment: begin
                memAdr = cmdreg_stable[5:3];
                operation = cmdreg_stable[7:6];
                readyBit = cmdreg_stable[0];
            end
            
            //use a mux to decide weather to use these or not
            offset: begin
                memAdr = cmdreg_stable[5:3];
                operation = cmdreg_stable[7:6];
                readyBit = cmdreg_stable[0];
            end 
            
            mult: begin
                memAdr = cmdreg_stable[5:3];
                operation = cmdreg_stable[7:6];
                readyBit = cmdreg_stable[0];
            end
            
            default: begin
                memAdr = 3'b000;
                operation = 2'b00;
                readyBit = 1'b0;
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
