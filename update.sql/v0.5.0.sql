ALTER TABLE `blok` CONVERT TO CHARACTER SET utf8;
ALTER TABLE `command` CONVERT TO CHARACTER SET utf8;
ALTER TABLE `event` CONVERT TO CHARACTER SET utf8;
ALTER TABLE `event_ausweis` CONVERT TO CHARACTER SET utf8;
ALTER TABLE `event_money` CONVERT TO CHARACTER SET utf8;
ALTER TABLE `event_necombat` CONVERT TO CHARACTER SET utf8;
ALTER TABLE `msg` CONVERT TO CHARACTER SET utf8;
ALTER TABLE `preedit` CONVERT TO CHARACTER SET utf8;
ALTER TABLE `preedit_field` CONVERT TO CHARACTER SET utf8;
ALTER TABLE `print_ausweis` CONVERT TO CHARACTER SET utf8;
ALTER TABLE `print_party` CONVERT TO CHARACTER SET utf8;
ALTER TABLE `user_group` CONVERT TO CHARACTER SET utf8;
ALTER TABLE `user_list` CONVERT TO CHARACTER SET utf8;
ALTER TABLE `user_session` CONVERT TO CHARACTER SET utf8;

ALTER TABLE `user_session`
	CHANGE COLUMN `create` `dtbeg` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
	CHANGE COLUMN `visit` `dtact` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
    DROP COLUMN `state`,
    CHANGE COLUMN `op` `state` char(128) DEFAULT NULL,
	ADD `form` text DEFAULT NULL;

ALTER TABLE `user_list`
    DROP COLUMN `family`,
    DROP COLUMN `name`,
    DROP COLUMN `otch`,
    DROP COLUMN `phone`;
