CREATE PROCEDURE simpleproc (OUT param1 INT)
    BEGIN
        SELECT COUNT(*) INTO param1 FROM example;
    END;

