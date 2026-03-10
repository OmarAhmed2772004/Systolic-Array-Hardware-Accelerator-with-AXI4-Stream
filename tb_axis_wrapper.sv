
module tb_axis_wrapper;

    localparam N = 2;
    localparam DWIDTH = 8;
    localparam PWIDTH = 16;

    logic clk;
    logic rst_n;
    logic load_weight;
    logic [(N*N*DWIDTH)-1:0] weight_in_flat;
    logic [(N*DWIDTH)-1:0]   s_axis_tdata;
    logic                    s_axis_tvalid;
    logic                    s_axis_tready;
    logic [(N*PWIDTH)-1:0]   m_axis_tdata;
    logic                    m_axis_tvalid;
    logic                    m_axis_tready;

    axis_systolic_wrapper #(.N(N), .DWIDTH(DWIDTH), .PWIDTH(PWIDTH)) dut (.*);

    always #5 clk = ~clk;

    logic [PWIDTH-1:0] out_row0, out_row1;
    assign out_row0 = m_axis_tdata[0 +: PWIDTH];
    assign out_row1 = m_axis_tdata[PWIDTH +: PWIDTH];

    initial begin
        clk = 0; rst_n = 0;
        load_weight = 0; weight_in_flat = '0;
        s_axis_tvalid = 0; s_axis_tdata = '0;
        m_axis_tready = 1; 

        $display("\n===========================================");
        $display("   PHASE 2: AXI4-STREAM SYSTOLIC TEST");
        $display("===========================================\n");

        #12 rst_n = 1; 

        // Load Weights
        weight_in_flat = {8'd3, 8'd1, 8'd0, 8'd2};
        load_weight = 1;
        #10 load_weight = 0;
        
        // Push Column 0
        s_axis_tdata = {8'd0, 8'd4}; 
        s_axis_tvalid = 1;
        wait_for_ready();

        // Push Column 1
        s_axis_tdata = {8'd2, 8'd5};
        s_axis_tvalid = 1;
        wait_for_ready();

        // Inject Stall
        $display(" [STALL INJECTED] Pipeline freezing");
        s_axis_tvalid = 0; 
        m_axis_tready = 0; 
        #20;               
        $display(" [STALL REMOVED] Pipeline resuming\n");
        m_axis_tready = 1;

        // Push Zeros to flush
        s_axis_tdata = {8'd0, 8'd0};
        s_axis_tvalid = 1;
        wait_for_ready();

        s_axis_tdata = {8'd0, 8'd0};
        s_axis_tvalid = 1;
        wait_for_ready();
        s_axis_tvalid = 0; 
    end

    task wait_for_ready();
        @(posedge clk);
        while (!s_axis_tready) @(posedge clk);
    endtask

    
    int valid_count = 0;
    always @(posedge clk) begin
        if (rst_n && m_axis_tvalid && m_axis_tready) begin
            valid_count++;
            $display("Time %0t: Output | Row 0 = %2d | Row 1 = %2d", $time, out_row0, out_row1);

            if (valid_count == 1) begin
                if (out_row0 !== 8) $error("FAIL Out 1 Row 0"); else $display("   [PASS] Out 1 Row 0 = 8");
            end else if (valid_count == 2) begin
                if (out_row0 !== 12) $error("FAIL Out 2 Row 0"); else $display("   [PASS] Out 2 Row 0 = 12");
            end else if (valid_count == 3) begin
                if (out_row1 !== 6)  $error("FAIL Out 3 Row 1"); else $display("   [PASS] Out 3 Row 1 = 6");
            end else if (valid_count == 4) begin
                $display("\n ALL PROTOCOL & MATH TESTS PASSED \n");
                $finish;
            end
        end
    end
endmodule
