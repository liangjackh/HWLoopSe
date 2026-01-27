module place_holder (
  input  CLK,
  input  RST,
  // 修改 1: 声明为 reg 类型以便在 always 块赋值
  // 修改 2: 声明为 [31:0] 以避免位宽截断警告
  output reg [31:0] out 
);
  
  // 修改 3: 中间连线 out_wire 也需要匹配位宽，否则会截断子模块的输出
  wire [31:0] out_wire; 
  
  always @(posedge CLK) begin
    if (RST) begin
      out <= 0;
    end
    else begin
      // 现在 out 和 out_wire 都是 32 位，加法逻辑正常
      out <= out + 1 + out_wire;
    end
  end
  
  //place_holder_2 test_1(
  //  .CLK (CLK),
  //  .RST (RST),
  //  .out (out_wire)
  //);
  
endmodule

module place_holder_2 (
  input  CLK,
  input  RST,
  // 修改 4: 子模块输出同样修改为 reg [31:0]
  output reg [31:0] out 
);
  
  always @(posedge CLK) begin
    if (RST) begin
      out <= 0;
    end
    else begin
      // +2 操作现在在 32 位下有意义
      out <= out + 2;
    end
    assert (out % 2 == 0) else begin
      $error("Assertion failed: out is not even!");
    end
  end
    
endmodule

// 验证模块
//module place_holder_props (
//  input CLK,
//  input RST,
//  input [31:0] out,
//  input [31:0] out_wire
//);
//
//  // ------------------------------------------
//  // 辅助逻辑：记录复位后的周期数
//  // ------------------------------------------
//  reg [31:0] cycle_cnt;
//  
//  always @(posedge CLK) begin
//    if (RST) begin
//      cycle_cnt <= 0;
//    end else begin
//      cycle_cnt <= cycle_cnt + 1;
//    end
//  end
//
//  // ------------------------------------------
//  // Property 1: 验证 out 必须等于 cycle_cnt 的平方
//  // ------------------------------------------
//  property p_square_function;
//    @(posedge CLK) disable iff (RST)
//    // 只有在没有溢出的范围内验证，避免32位溢出误报
//    (cycle_cnt < 65535) |-> (out == cycle_cnt * cycle_cnt);
//  endproperty
//
//  assert_square: assert property (p_square_function)
//    else $error("[ASSERT FAIL] out is not square of cycles! out=%0d, cycle=%0d", out, cycle_cnt);
//
//  // ------------------------------------------
//  // Property 2: 验证子模块 out_wire 始终是偶数
//  // ------------------------------------------
//  property p_wire_even;
//    @(posedge CLK) disable iff (RST)
//    (out_wire[0] == 1'b0);
//  endproperty
//
//  assert_even: assert property (p_wire_even)
//    else $error("[ASSERT FAIL] out_wire should be even!");
//
//endmodule
//
//// 绑定语句 (放在 testbench 或此时即可)
//bind place_holder place_holder_props u_sva (.*);