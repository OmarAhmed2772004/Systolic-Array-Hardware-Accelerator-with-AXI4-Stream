
module mac_pe #(
    parameter DWIDTH = 8,
    parameter PWIDTH = 16
)(
    input  logic clk,
    input  logic rst_n,
    input  logic en,             
    input  logic load_weight,
    input  logic [DWIDTH-1:0] weight_in,
    input  logic [DWIDTH-1:0] act_in,
    input  logic [PWIDTH-1:0] psum_in,
    output logic [DWIDTH-1:0] act_out,
    output logic [PWIDTH-1:0] psum_out
);

    logic [DWIDTH-1:0] weight_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            weight_reg <= '0;
            act_out    <= '0;
            psum_out   <= '0;
        end else if (en) begin  
            if (load_weight) begin
                weight_reg <= weight_in;
            end else begin
                act_out <= act_in;
                if (act_in != 0 && weight_reg != 0) begin
                    psum_out <= psum_in + (act_in * weight_reg);
                end else begin
                    psum_out <= psum_in;
                end
            end
        end
    end
endmodule
