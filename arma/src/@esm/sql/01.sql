-- Adds `esm_custom_id` to territory. This field is used for storing the custom ID set by the `set_id` command
ALTER TABLE territory ADD COLUMN `esm_custom_id` VARCHAR(100) NULL AFTER `id`, ADD UNIQUE INDEX `esm_custom_id_UNIQUE` (`esm_custom_id` ASC);

-- Adds `esm_payment_counter` to territory. This field is used to track how many times a territory has been paid for by using ESM
ALTER TABLE territory ADD COLUMN `esm_payment_counter` INT(11) UNSIGNED NOT NULL DEFAULT '0' AFTER `moderators`;
