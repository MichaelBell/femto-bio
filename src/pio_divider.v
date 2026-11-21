// (c) Copyright 2024 CrossBar, Inc.
//
// SPDX-FileCopyrightText: 2024 CrossBar, Inc.
// SPDX-License-Identifier: BSD-2-Clause
//
// This file may have been modified and is redistributed by CrossBar, Inc.
//
// You may redistribute and modify this documentation under the terms of the
// License. This documentation and source code is distributed WITHOUT ANY EXPRESS
// OR IMPLIED WARRANTY, MERCHANTABILITY, SATISFACTORY QUALITY OR FITNESS FOR A
// PARTICULAR PURPOSE. Please see the License for the specific language governing
// permissions and limitations under the License.

// SPDX-FileCopyrightText: 2022 Lawrie Griffiths
// SPDX-License-Identifier: BSD-2-Clause

// Modifications: Michael Bell 2026

// `default_nettype none
module pio_divider (
  input         clk,
  input         reset,
  input [15:0]  div_int,
  input [7:0]   div_frac,
  input         div_set,
  output [23:0] div_out,
  output reg    penable
);
  wire use_divider;
  wire divint_1;

  wire [23:0] div;
  reg [23:0] div_counter;
  reg pen;
  reg old_pen;
  // bring the clock dividers into the local clock domain
  // this cleans up false path timing errors from AHB domain on
  // a critical signal
  reg [15:0] div_int_r;
  reg [7:0] div_frac_r;

  assign div = {div_int_r, div_frac_r};
  assign use_divider = div[23:8] != 0;
  assign divint_1 = (div[23:8] == 16'd1);

  always @(posedge clk) begin
    if (reset) begin
      div_int_r <= 0;
      div_frac_r <= 0;
    end else if (div_set) begin
      div_int_r <= div_int;
      div_frac_r <= div_frac;
    end
  end
  always @(posedge clk) begin
    if (reset) begin
      div_counter <= 0;
      pen <= 1;
      old_pen <= 0;
      penable <= 0;
    end else begin
      penable <= ((pen & ~old_pen) || !use_divider) ^ divint_1;
      if (use_divider) begin
        old_pen <= pen;
        div_counter <= div_counter + 256;
        if (div_counter >= div - 256)
          div_counter <= div_counter - (div - 256);
        pen <= div_counter < (div >> 1);
      end
    end
  end

  assign div_out = div;
endmodule
