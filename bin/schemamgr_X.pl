#!/usr/bin/perl

# SchemaMgr is a simple tool to manage schema change in MySQL DBs.  
#  Author: Neal Richter 
#  Perl code written in 2007
#  Currently used a a production tool


# Copyright 2011 Neal Richter. All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without modification, are
# permitted provided that the following conditions are met:
# 
#    1. Redistributions of source code must retain the above copyright notice, this list of
#       conditions and the following disclaimer.
# 
#    2. Redistributions in binary form must reproduce the above copyright notice, this list
#       of conditions and the following disclaimer in the documentation and/or other materials
#       provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY NEAL RICHTER ``AS IS'' AND ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
# FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL NEAL RICHTER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
# ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


##  --- CONSTANTS ---


my $DEFAULT_TARGET_VERSION =  "999999";
my $DB_NAME =  "X";
my $DB_PORT =  "3306";
my $DB_PROTOCOL = "tcp";
my $DB_HOSTNAME = "localhost";

##  --- VARIABLES ---

my $db_user_name = "";
my $db_password = "";
my $backup = false;
my $target_version = $DEFAULT_TARGET_VERSION;
my $current_db_version = 1;

my $debug_level = 1;

##  --- USAGE MESSAGE ---

sub usage {
	print "Usage: either create or upgrade $DB_NAME database\n";
	print "\tschemamgr_X.pl -i -uUSERNAME -pPASSWORD [-vVERSION] [-b]\n";
	print "\t\t updates DB of to current (default) or requested version\n";
	print "\tschemamgr_X.pl -s -uUSERNAME -pPASSWORD\n";
	print "\t\t reinstalls all stored procedures\n";
	print "\tschemamgr_X.pl -w -uUSERNAME -pPASSWORD \n";
	print "\t\t reinstalls all views\n";
	print "\tschemamgr_X.pl -q -uUSERNAME -pPASSWORD \n";
	print "\t\t Requests and prints current version\n";
	print "Optional Params \n";
	print "\t -vXX -- upgrades upto a specific version number XX \n";
	print "\t -b   -- backs up the database (with data) before upgrades \n";
	print "\t -nYY -- runs the upgrades against database YY - default is $DB_NAME \n";
#	print "\t -mZZ -- runs the upgrades against database server ZZ - default is $DB_HOSTNAME \n";
        exit;
}

# --------- Utility Funcs ------------------

sub trim {
  my $string = shift;
  for ($string) {
    s/^\s+//;
    s/\s+$//;
  }
  return $string;
}

sub trim_arg {
  my $string = shift;
  for ($string) {
    s/^\s+//;
    s/\s+$//;
    s/^\-.//;
  }
  return $string;
}

sub get_file_vernum
{
  my $string = shift;
  for ($string) {
    s/.*_objects_v//;  #filename
    s/_20.*\.sql//;    #year
  }
  return $string;
}

sub debug_print{
  my $string = shift;
  if($debug_level > 0)
  { print $string; }
}

## ------------ working subroutines ---------
	
sub create_backup_sqldump
{
	$backup_dump_file  = "db_$DB_HOSTNAME_$DB_NAME" . "_ver";

	$backup_dump_file .= get_current_db_version();

	$backup_dump_file .= "_" . time() . "_sqldump";

	debug_print "Current DB dumped to $backup_dump_file.gz\n";
	
	system("mysqldump -ecq --host=$DB_HOSTNAME -u$db_user_name -p$db_password --port=$DB_PORT --protocol=$DB_PROTOCOL $DB_NAME > $backup_dump_file");
	system("gzip $backup_dump_file");

	return $backup_dump_file . ".gz";
}

sub dump_current_schema
{
	$schema_dump_file  = "db_$DB_HOSTNAME_$DB_NAME" . "_ver";

	$schema_dump_file .= get_current_db_version();

	$schema_dump_file .= "_schema_dump.sql";

	debug_print "Current DB Schema dumped to $schema_dump_file\n";
	
	system("mysqldump -d --host=$DB_HOSTNAME -u$db_user_name -p$db_password --port=$DB_PORT --protocol=$DB_PROTOCOL $DB_NAME > $schema_dump_file");

	return $schema_dump_file;
}

sub get_current_db_version
{
	my $infile = "/tmp/DB_SCHEMA_VERSION";
	my $curr_db_ver = "";

	$err = system("mysql --host=$DB_HOSTNAME -u$db_user_name -p$db_password --port=$DB_PORT --protocol=$DB_PROTOCOL $DB_NAME -e \" SELECT value from cc_db_configuration where key_name = 'DB_SCHEMA_VERSION'  \" > $infile ");

	if($err != 0)
	{
		return -1;
	}

	open (INFILE1, $infile) or die "Can't open $infile1: $!\n";

	while(<INFILE1>)
	{
		$_ = trim($_);
		s/^value//;
		$curr_db_ver = $_;
	}

	close INFILE1;

	return $curr_db_ver;
}

sub get_max_sql_script_number
{

  	my $tmp_version = -1;
	my $tmpfile = "/tmp/DB_UPGRADE_SCRIPTS";

	$test = system("ls ./build/c*_objects_v*_*.sql ./build/u*_objects_v*_*.sql | sort > $tmpfile ");

	open (TMPFILE1, $tmpfile) or die "Can't open $tmpfile: $!\n";

	my @sql_file_array;
	my $i = 0;

	while(<TMPFILE1>)
	{
   		$clean_line = trim($_);
		$sql_file_array[$i] = $clean_line;
		#debug_print(" file - [$clean_line] - [ $sql_file_array[$i] ]\n");

		$i++;
	}

	close TMPFILE1;
  
	foreach (@sql_file_array)
	{
		my $inum = get_file_vernum($_);

		if($inum > $tmp_version)
		{
			$tmp_version = $inum;
		}
	}

	return $tmp_version;
}

sub exec_sql_upgrade_scripts 
{
  	my $cur_db_version = shift;
  	my $stop_db_version = shift;
	my $tmpfile = "/tmp/DB_UPGRADE_SCRIPTS";

	$test = system("ls ./build/c*_objects_v*_*.sql ./build/u*_objects_v*_*.sql | sort > $tmpfile ");

	open (TMPFILE1, $tmpfile) or die "Can't open $tmpfile: $!\n";

	my @sql_file_array;
	my $i = 0;

	while(<TMPFILE1>)
	{
   		$clean_line = trim($_);
		$sql_file_array[$i] = $clean_line;
		#debug_print(" file - [$clean_line] - [ $sql_file_array[$i] ]\n");

		$i++;
	}

	close TMPFILE1;
  
	@sorted_sql_file_array = sort { ($a =~ /_v(\d+)_/)[0] <=> ($b =~ /_v(\d+)_/)[0] } @sql_file_array;

	foreach (@sorted_sql_file_array)
	{
		my $inum = get_file_vernum($_);

		if(($inum > $cur_db_version) && ($inum <= $stop_db_version))
		{
			print "Executing step $inum - sql [$_] \n";

			# 1 exec script
			$err = system("mysql --host=$DB_HOSTNAME -u$db_user_name -p$db_password --port=$DB_PORT --protocol=$DB_PROTOCOL $DB_NAME < $_ ");
			
			# if no error, write new ver to DB
			if($err == 0)
			{
				system("mysql --host=$DB_HOSTNAME -u$db_user_name -p$db_password --port=$DB_PORT --protocol=$DB_PROTOCOL $DB_NAME -e \" UPDATE cc_db_configuration set value = '$inum' where key_name = 'DB_SCHEMA_VERSION'  \" ");
				$cur_db_version = $inum;
			}
			else
			{
				print "!!!FATAL ERROR with SQL in step [$inum] !! .. exiting\n";
				exit;
			}
		}
		else
		{
			print "Skipping step $inum - sql [$_] - CV [$cur_db_version] \n";
		}
	}
}

sub exec_sql_reinstall_sql_files 
{
  	my $working_patterns = shift;
	my $tmpfile = "/tmp/DB_UPGRADE_PROCEDURES";

	$count = `ls $working_patterns | wc -l`;

	if ($count == 0)
	{
		print "Nothing to reinstall for [$working_patterns].. exiting.\n";
		exit;
	}

	$test = system("ls ".$working_patterns ." | sort > $tmpfile ");

	open (TMPFILE1, $tmpfile) or die "Can't open $tmpfile: $!\n";

	my @sql_file_array;
	my $i = 0;

	while(<TMPFILE1>)
	{
   		$clean_line = trim($_);
		$sql_file_array[$i] = $clean_line;
		#debug_print(" file - [$clean_line] - [ $sql_file_array[$i] ]\n");

		$i++;
	}

	close TMPFILE1;
  
	foreach (@sql_file_array)
	{
		print "Installing [$_] \n";

		# 1 exec script
		$err = system("mysql --host=$DB_HOSTNAME -u$db_user_name -p$db_password --port=$DB_PORT --protocol=$DB_PROTOCOL $DB_NAME < $_ ");
			
		# if error, barf and exit
		if($err != 0)
		{
			print "!!!FATAL ERROR with SQL in step [$inum] !! .. exiting\n";
			exit;
		}
	}
}


##  ----------------------------- MAIN ----------------------------------------

##  --- argument processing ---


#process arguments in any order
while (@ARGV) 
{
  $argument = shift @ARGV;
  $arg_short = substr $argument, 0, 2;
  #print "ARG: $argument [$arg_short]\n";

  if    ( $arg_short eq "-h") { usage(); }
  elsif ( $arg_short eq "-q") { $command = $arg_short; }
  elsif ( $arg_short eq "-i") { $command = $arg_short; }
  elsif ( $arg_short eq "-s") { $command = $arg_short; print "Reinstalling Stored Procedures..\n"; }
  elsif ( $arg_short eq "-w") { $command = $arg_short; print "Reinstalling Views..\n"; }
  elsif ( $arg_short eq "-b") { $backup = true; }
  elsif ( $arg_short eq "-v") { $target_version = trim_arg($argument); if(length($target_version)<1) {$target_version = $DEFAULT_TARGET_VERSION}  }
  elsif ( $arg_short eq "-n") { $DB_NAME = trim_arg($argument); }
  elsif ( $arg_short eq "-u") { $db_user_name = trim_arg($argument); }
  elsif ( $arg_short eq "-p") { $db_password = trim_arg($argument); }
  elsif ( $arg_short eq "-m") { $DB_HOSTNAME = trim_arg($argument); }

  else  { usage(); }
}

if( ( length($db_user_name) < 1 ) || ( length($db_password) < 1 ) )
{
	print "ERROR: bad username/password arguments \n";
	usage();
	exit;
}
	
	
print "SQL-DB $DB_HOSTNAME : $DB_NAME : $db_user_name : $db_password\n";
#print "COMMAND: $command\n";

#-------------------------------------------------
#execute commands

if ( $command eq "-i") 
{
	# 1 Upgrade existing DB
	
	# 2 Get the DB version # from MySQL
	
	$current_db_version =  get_current_db_version();

	if($target_version == $DEFAULT_TARGET_VERSION)
	{
		$target_version = get_max_sql_script_number();
	}

	print "\nSQL-DB version [$current_db_version]  => UPGRADE to [$target_version]\n";

	if($current_db_version == $target_version)
	{
		print "Done .. (nothing to do)\n";
		exit;
	}
	elsif($current_db_version > $target_version)
	{
		print "Done .. (db version is greater than given version)\n";
		exit;
	}

	# 3 backup step
	if ( $backup != false)
	{
		my $sqlbackupfile = create_backup_sqldump();
		print "Old DB backed-up to [$sqlbackupfile]\n";
	}

	# 4 Execute SQL files
	
	exec_sql_upgrade_scripts($current_db_version, $target_version);

	# 5 Dump Current Schema & Report

	$new_db_version =  get_current_db_version();
	$new_db_schema =  dump_current_schema();

	print "New SQL-DB version is [$new_db_version]\n";
	#print "New SQL-DB Schema written to [$new_db_schema]\n";

}
elsif ( $command eq "-s") 
{	
	exec_sql_reinstall_sql_files("./build/procedures/procedure_*.sql");
}
elsif ( $command eq "-w") 
{	
	exec_sql_reinstall_sql_files("./build/views/view_*.sql");
}
elsif ( $command eq "-q") 
{	
	$current_db_version =  get_current_db_version();
        print "Current Schema Version:$current_db_version\n";
        exit;
}
	
print "Done.\n";


exit; 
