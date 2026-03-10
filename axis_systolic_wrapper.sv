// ---------------------------------------------------------
// Module: axis_systolic_wrapper 
// ---------------------------------------------------------
module axis_systolic_wrapper #(
    parameter N = 2,
    parameter DWIDTH = 8,
    parameter PWIDTH = 16
)(
    input  logic clk,
    input  logic rst_n,

    input  logic load_weight,
    input  logic [(N*N*DWIDTH)-1:0] weight_in_flat,

    input  logic [(N*DWIDTH)-1:0] s_axis_tdata,
    input  logic                  s_axis_tvalid,
    output logic                  s_axis_tready,

    output logic [(N*PWIDTH)-1:0] m_axis_tdata,
    output logic                  m_axis_tvalid,
    input  logic                  m_axis_tready
);

    logic [DWIDTH-1:0] weight_in_2d [N-1:0][N-1:0];
    logic [DWIDTH-1:0] act_in_staggered [N-1:0];
    logic [PWIDTH-1:0] psum_out_raw [N-1:0];
    
    genvar i, j;
    generate
        for (i = 0; i < N; i++) begin : unpack_row
            for (j = 0; j < N; j++) begin : unpack_col
                assign weight_in_2d[i][j] = weight_in_flat[((i*N+j)*DWIDTH) +: DWIDTH];
            end
        end
    endgenerate

    assign s_axis_tready = m_axis_tready; 

    // PIPELINE ADVANCE: Always move if downstream memory is ready
    logic advance_pipeline;
    assign advance_pipeline = m_axis_tready;

    // BUBBLE INJECTION: If data is invalid, feed zeros so the math flushes out
    logic [(N*DWIDTH)-1:0] safe_tdata;
    assign safe_tdata = s_axis_tvalid ? s_axis_tdata : '0;

    logic core_en;
    assign core_en = advance_pipeline || load_weight;

    logic [DWIDTH-1:0] delay_lines [N-1:0][N:1]; 

    generate
        for (i = 0; i < N; i++) begin : stagger_rows
            if (i == 0) begin
                assign act_in_staggered[i] = safe_tdata[(i*DWIDTH) +: DWIDTH];
            end else begin
                always_ff @(posedge clk or negedge rst_n) begin
                    if (!rst_n) begin
                        for (int d = 1; d <= i; d++) begin
                            delay_lines[i][d] <= '0;
                        end
                    end else if (advance_pipeline) begin
                        delay_lines[i][1] <= safe_tdata[(i*DWIDTH) +: DWIDTH];
                        for (int d = 1; d < i; d++) begin
                            delay_lines[i][d+1] <= delay_lines[i][d]; 
                        end
                    end
                end
                assign act_in_staggered[i] = delay_lines[i][i];
            end
        end
    endgenerate

    logic [N-1:0] valid_pipeline;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_pipeline <= '0;
        end else if (advance_pipeline) begin
            valid_pipeline <= {valid_pipeline[N-2:0], s_axis_tvalid}; 
        end
    end
    assign m_axis_tvalid = valid_pipeline[N-1];

    systolic_array #(
        .N(N), .DWIDTH(DWIDTH), .PWIDTH(PWIDTH)
    ) core_inst (
        .clk(clk),
        .rst_n(rst_n),
        .en(core_en),
        .load_weight(load_weight),
        .weight_in(weight_in_2d),
        .act_in(act_in_staggered),
        .psum_out(psum_out_raw)
    );

    generate
        for (i = 0; i < N; i++) begin : pack_outputs
            assign m_axis_tdata[(i*PWIDTH) +: PWIDTH] = psum_out_raw[i];
        end
    endgenerate

endmodule