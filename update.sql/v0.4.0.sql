CREATE TABLE `msg` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `uid` int(11) unsigned NOT NULL DEFAULT '0',
  `cmdid` int(11) unsigned NOT NULL DEFAULT '0',
  `dtadd` datetime NOT NULL,
  `readed` tinyint(1) unsigned NOT NULL DEFAULT '0',
  `mailed` tinyint(1) unsigned DEFAULT NULL,
  `txt` text NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `id` (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=cp1251;

