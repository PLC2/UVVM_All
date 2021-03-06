--================================================================================================================================
-- Copyright 2020 Bitvis
-- Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0 and in the provided LICENSE.TXT.
--
-- Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
-- an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and limitations under the License.
--================================================================================================================================
-- Note : Any functionality not explicitly described in the documentation is subject to change at any time
----------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------
-- Description   : See library quick reference (under 'doc') and README-file(s)
------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.textio.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;


--===========================================================================================
package gpio_bfm_pkg is

  --=========================================================================================
  -- Types and constants for GPIO BFM
  --=========================================================================================
  constant C_SCOPE : string := "GPIO BFM";

  -- Configuration record to be assigned in the test harness.
  type t_gpio_bfm_config is
  record
    clock_period     : time;
    match_strictness : t_match_strictness; -- Matching strictness for std_logic values in check procedures.
    id_for_bfm       : t_msg_id;           -- The message ID used as a general message ID in the GPIO BFM
    id_for_bfm_wait  : t_msg_id;           -- The message ID used for logging waits in the GPIO BFM.
    id_for_bfm_poll  : t_msg_id;           -- The message ID used for logging polling in the GPIO BFM
  end record;

  -- Define the default value for the BFM config
  constant C_GPIO_BFM_CONFIG_DEFAULT : t_gpio_bfm_config := (
    clock_period     => -1 ns,
    match_strictness => MATCH_STD,
    id_for_bfm       => ID_BFM,
    id_for_bfm_wait  => ID_BFM_WAIT,
    id_for_bfm_poll  => ID_BFM_POLL
    );


  --=========================================================================================
  -- BFM procedures
  --=========================================================================================

  ---------------------------------------------------------------------------------
  -- set data
  ---------------------------------------------------------------------------------
  procedure gpio_set (
    constant data_value   : in    std_logic_vector;  -- '-' means don't change
    constant msg          : in    string;
    signal data_port      : inout std_logic_vector;
    constant scope        : in    string         := C_SCOPE;
    constant msg_id_panel : in    t_msg_id_panel := shared_msg_id_panel
    );

  ---------------------------------------------------------------------------------
  -- get data()
  ---------------------------------------------------------------------------------
  procedure gpio_get (
    variable data_value   : out std_logic_vector;
    constant msg          : in  string;
    signal data_port      : in  std_logic_vector;
    constant scope        : in  string         := C_SCOPE;
    constant msg_id_panel : in  t_msg_id_panel := shared_msg_id_panel
    );

  ---------------------------------------------------------------------------------
  -- check data()
  ---------------------------------------------------------------------------------
  -- Perform a read operation, then compare the read value to the expected value.
  procedure gpio_check (
    constant data_exp     : in std_logic_vector;  -- '-' means don't care
    constant msg          : in string;
    signal data_port      : in std_logic_vector;
    constant alert_level  : in t_alert_level     := error;
    constant scope        : in string            := C_SCOPE;
    constant msg_id_panel : in t_msg_id_panel    := shared_msg_id_panel;
    constant config       : in t_gpio_bfm_config := C_GPIO_BFM_CONFIG_DEFAULT
    );

  ---------------------------------------------------------------------------------
  -- expect data()
  ---------------------------------------------------------------------------------
  -- Perform a read operation, then compare the read value to the expected value.
  procedure gpio_expect (
    constant data_exp     : in std_logic_vector;
    constant msg          : in string;
    signal data_port      : in std_logic_vector;
    constant timeout      : in time              := 0 ns;  -- 0 = no timeout
    constant alert_level  : in t_alert_level     := error;
    constant scope        : in string            := C_SCOPE;
    constant msg_id_panel : in t_msg_id_panel    := shared_msg_id_panel;
    constant config       : in t_gpio_bfm_config := C_GPIO_BFM_CONFIG_DEFAULT
    );

end package gpio_bfm_pkg;


--=================================================================================
--=================================================================================

package body gpio_bfm_pkg is

  ---------------------------------------------------------------------------------
  -- set data
  ---------------------------------------------------------------------------------
  procedure gpio_set (
    constant data_value   : in    std_logic_vector;  -- '-' means don't change
    constant msg          : in    string;
    signal data_port      : inout std_logic_vector;
    constant scope        : in    string         := C_SCOPE;
    constant msg_id_panel : in    t_msg_id_panel := shared_msg_id_panel
    ) is
    constant name         : string := "gpio_set(" & to_string(data_value) & ")";
    constant c_data_value : std_logic_vector(data_port'range) := data_value;
  begin

    for i in 0 to data_port'length-1 loop --data_port'range loop
      if c_data_value(i) /= '-' then
        data_port(i) <= c_data_value(i);
      end if;
    end loop;
    log(ID_BFM, name & " completed. " & add_msg_delimiter(msg), scope, msg_id_panel);
  end procedure;


  ---------------------------------------------------------------------------------
  -- get data()
  ---------------------------------------------------------------------------------
  -- Perform a read operation and returns the gpio value
  procedure gpio_get (
    variable data_value   : out std_logic_vector;
    constant msg          : in  string;
    signal data_port      : in  std_logic_vector;
    constant scope        : in  string         := C_SCOPE;
    constant msg_id_panel : in  t_msg_id_panel := shared_msg_id_panel
    ) is
    constant name         : string := "gpio_get()";
  begin
    log(ID_BFM, name & " => Read gpio value: " & to_string(data_port, HEX_BIN_IF_INVALID, AS_IS, INCL_RADIX) & ". " & add_msg_delimiter(msg), scope, msg_id_panel);
    data_value := data_port;
  end procedure;


  ---------------------------------------------------------------------------------
  -- check data()
  ---------------------------------------------------------------------------------
  -- Perform a read operation, then compare the read value to the expected value.
  procedure gpio_check (
    constant data_exp     : in std_logic_vector;  -- '-' means don't care
    constant msg          : in string;
    signal data_port      : in std_logic_vector;
    constant alert_level  : in t_alert_level     := error;
    constant scope        : in string            := C_SCOPE;
    constant msg_id_panel : in t_msg_id_panel    := shared_msg_id_panel;
    constant config       : in t_gpio_bfm_config := C_GPIO_BFM_CONFIG_DEFAULT
    ) is
    constant name          : string := "gpio_check(" & to_string(data_exp, HEX, AS_IS, INCL_RADIX) & ")";
    constant c_data_exp    : std_logic_vector(data_port'range) := data_exp;
    variable v_check_ok    : boolean := true;
    variable v_alert_radix : t_radix;
  begin
    for i in c_data_exp'range loop
      -- Allow don't care in expected value and use match strictness from config for comparison
      if c_data_exp(i) = '-' or check_value(data_port(i), c_data_exp(i), config.match_strictness, NO_ALERT, msg) then
        v_check_ok := true;
      else
        v_check_ok := false;
        exit;
      end if;
    end loop;

    if not v_check_ok then
      -- Use binary representation when mismatch is due to weak signals
      v_alert_radix := BIN when config.match_strictness = MATCH_EXACT and check_value(data_port, c_data_exp, MATCH_STD, NO_ALERT, msg) else HEX;
      alert(alert_level, name & "=> Failed. Was " & to_string(data_port, v_alert_radix, AS_IS, INCL_RADIX) & ". Expected " & to_string(c_data_exp, v_alert_radix, AS_IS, INCL_RADIX) & "." & LF & add_msg_delimiter(msg), scope);
    else
      log(ID_BFM, name & "=> OK, read data = " & to_string(data_port, HEX_BIN_IF_INVALID, AS_IS, INCL_RADIX) & ". " & add_msg_delimiter(msg), scope, msg_id_panel);
    end if;
  end procedure;

  ---------------------------------------------------------------------------------
  -- expect()
  ---------------------------------------------------------------------------------
  -- Perform a receive operation, then compare the received value to the expected value.
  procedure gpio_expect (
    constant data_exp     : in std_logic_vector;
    constant msg          : in string;
    signal data_port      : in std_logic_vector;
    constant timeout      : in time              := 0 ns;  -- 0 = no timeout
    constant alert_level  : in t_alert_level     := error;
    constant scope        : in string            := C_SCOPE;
    constant msg_id_panel : in t_msg_id_panel    := shared_msg_id_panel;
    constant config       : in t_gpio_bfm_config := C_GPIO_BFM_CONFIG_DEFAULT
    ) is
    constant name         : string := "gpio_expect(" & to_string(data_exp, HEX, AS_IS, INCL_RADIX) & ")";
    constant c_data_exp   : std_logic_vector(data_port'range) := data_exp;
  begin
    log(ID_BFM, name & "=> Expecting value " & to_string(data_exp, HEX_BIN_IF_INVALID, AS_IS, INCL_RADIX) & "." & add_msg_delimiter(msg), scope, msg_id_panel);
    await_value(data_port, c_data_exp, config.match_strictness, 0 ns, timeout, alert_level, msg, scope, HEX_BIN_IF_INVALID, SKIP_LEADING_0, ID_BFM, msg_id_panel);
  end procedure;

end package body gpio_bfm_pkg;

