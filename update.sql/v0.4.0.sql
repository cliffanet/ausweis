CREATE TABLE `msg` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `uid` int(11) unsigned NOT NULL DEFAULT '0',
  `cmdid` int(11) unsigned NOT NULL DEFAULT '0',
  `dtadd` datetime NOT NULL,
  `readed` tinyint(1) unsigned NOT NULL DEFAULT '0',
  `mailed` tinyint(1) DEFAULT NULL,
  `txt` text NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `id` (`id`),
  KEY `uid` (`uid`),
  KEY `cmdid` (`cmdid`),
  KEY `dtadd` (`dtadd`),
  KEY `readed` (`readed`),
  KEY `mailed` (`mailed`)
) ENGINE=MyISAM DEFAULT CHARSET=cp1251;

ALTER TABLE `user_list`
	ADD `email` char(64) NOT NULL DEFAULT '',
	ADD KEY `email` (`email`);
