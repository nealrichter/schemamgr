
-- users  
CREATE TABLE anon_user (
  user_id INTEGER UNSIGNED NOT NULL AUTO_INCREMENT,
  cookie VARCHAR(128),
  dt_created TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY (user_id),

 INDEX idx_au_cookie(cookie)
)
ENGINE = InnoDB
CHARACTER SET utf8 COLLATE utf8_general_ci;

-- keywords  
CREATE TABLE keyword (
  keyword_id INTEGER UNSIGNED NOT NULL,
  value VARCHAR(128) NOT NULL,
  status INTEGER UNSIGNED NOT NULL default 1,
  quality_score INTEGER UNSIGNED NOT NULL default 0,
  PRIMARY KEY (keyword_id),

 INDEX idx_k_value (value)
)
ENGINE = InnoDB
CHARACTER SET utf8 COLLATE utf8_general_ci;
