-- This is a manually installed table to bootstrap dbaudit

CREATE TABLE `X_db_configuration` (
  `key_name` varchar(128) NOT NULL,
  `value` varchar(256) NOT NULL,
  `last_modified` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  PRIMARY KEY  (`key_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT INTO X_db_configuration (key_name,value) VALUES('DB_SCHEMA_VERSION', 0);
