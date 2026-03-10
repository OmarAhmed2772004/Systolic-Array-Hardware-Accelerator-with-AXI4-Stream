
module systolic_array #(
    parameter N = 2,
    parameter DWIDTH = 8,
    parameter PWIDTH = 16
)(
    input  logic clk,
    input  logic rst_n,
    input  logic en,            
    input  logic load_weight,
    input  logic [DWIDTH-1:0] weight_in [N-1:0][N-1:0],
    input  logic [DWIDTH-1:0] act_in    [N-1:0],
    output logic [PWIDTH-1:0] psum_out  [N-1:0]
);

    logic [DWIDTH-1:0] act_wires  [N-1:0][N:0];
    logic [PWIDTH-1:0] psum_wires [N:0][N-1:0];

    genvar i, j;
    
    generate
        for (i = 0; i < N; i++) begin : map_inputs
            assign act_wires[i][0] = act_in[i];
            assign psum_wires[0][i] = '0; 
        end
    endgenerate

    generate
        for (i = 0; i < N; i++) begin : row
            for (j = 0; j < N; j++) begin : col
                mac_pe #(
                    .DWIDTH(DWIDTH),
                    .PWIDTH(PWIDTH)
                ) pe_inst (
                    .clk(clk),
                    .rst_n(rst_n),
                    .en(en),              
                    .load_weight(load_weight),
                    .weight_in(weight_in[i][j]),
                    .act_in(act_wires[i][j]),
                    .psum_in(psum_wires[i][j]),
                    .act_out(act_wires[i][j+1]),
                    .psum_out(psum_wires[i+1][j])
                );
            end
        end
    endgenerate

    generate
        for (j = 0; j < N; j++) begin : map_outputs
            assign psum_out[j] = psum_wires[N][j];
        end
    endgenerate
endmodule
