--
-- PacketFence SQL schema upgrade from 7.0.0 to 7.1.0
--

--
-- Remove hash prefix from activation table
--

UPDATE activation SET activation_code = SUBSTR(activation_code, INSTR(activation_code, ":") + 1 );
