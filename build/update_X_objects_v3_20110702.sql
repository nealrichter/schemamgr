--
-- Alter Table structure for keyword
--
-- Comment: add new columns for stats
--    word_count:  number of words in the phrase
--    nlp_freq:  approximate frequency of the word in english data
--

ALTER TABLE keyword
	ADD COLUMN word_count INTEGER DEFAULT NULL,
	ADD COLUMN nlp_freq INTEGER DEFAULT NULL;

