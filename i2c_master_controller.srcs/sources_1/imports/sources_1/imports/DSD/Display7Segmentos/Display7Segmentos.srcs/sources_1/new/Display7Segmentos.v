`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08.09.2025 11:45:47
// Design Name: 
// Module Name: Display7Segmentos
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


module Display7Segmentos(
    input w,
    input x,
    input y,
    input z,
    output a,
    output b,
    output c,
    output d,
    output e,
    output f,
    output g
    );

// a = w'xy'z' + w'x'y'z + wxy'z + wx'yz
assign a = (~w &  x & ~y & ~z) |  // w'xy'z'
           (~w & ~x &  ~y & z) |  // w'x'y'z
           ( w &  x & ~y &  z) |  // wxy'z
           ( w & ~x &  y &  z);   // wx'yz

// b = w'xy'z + wyz + xyz' + wxz'
assign b = (~w &  x & ~y &  z) |  // w'xy'z
           ( w &       y &  z) |  // wyz
           (      x &  y & ~z) |  // xyz'
           ( w &  x &      ~z);   // wxz'

// c = w'x'y'z + wxy + wxz'
assign c = (~w & ~x &  y & ~z) |  // w'x'y'z
           ( w &  x &  y     ) | // wxy
           ( w &  x &      ~z);    // wxz'

// d = w'xy'z' + wx'yz' + x'y'z + xyz
assign d = (~w &  x & ~y & ~z) |  // w'xy'z'
           ( w & ~x &  y & ~z) |  // wx'yz'
           (    ~x & ~y  &  z) |   // x'y'z
           (     x &  y  &  z);    // xyz

// e = x'y'z + w'xy' + w'z
assign e = (     ~x &  ~y & z) |    // x'y'z
           (~w &  x &  ~y    ) |    // w'xy'
           (~w &            z);       // w'z

// f = wxy'z + w'yz + w'x'z + w'x'y
assign f = ( w &  x & ~y &  z) |  // wx'y'z
           (~w &       y &  z) |   // w'yz
           (~w & ~x &      z) |   // w'x'z
           (~w & ~x &  y);        // w'x'y

// g = wxy'z'+w'xyz+w'x'y' 
assign g = ( w & x & ~y & ~z) |  // wxy'z'
           (~w &  x &  y &  z) |  // w'xyz
           (~w & ~x & ~y);        // w'x'y'



endmodule
