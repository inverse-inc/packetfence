--
-- Swapping from integer to varchar on the trigger ids.
-- We can still do ranges because MySQL appropriately casts stuff.
--

ALTER TABLE `trigger`
	MODIFY `tid_start` varchar(255) NOT NULL,
	MODIFY `tid_end` varchar(255) NOT NULL
;
