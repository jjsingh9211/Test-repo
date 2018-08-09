#!/tools/perl/bin/perl
#
#Comment !
#
###########################################################################
#
#        State Street Bank and Trust Company
#
###########################################################################
#
#  Filename: job_control.pl
#
#  SCCS information:
#
#      version: 1.44
#      date changed: 03/02/05 13:56:57
#      date retrieved: 03/02/05
#
#
#  Description:
#
#       This Perl script is used to launch, monitor and kill processes.
#
###########################################################################
#
#    R E V I S I O N   L O G
#
#    Date       Name            Description
#    --------   --------------- -------------------------------
#    09/16/14   Nick Iagallo    Modified for Cloakware.
#    11/20/09   Nick Iagallo    Added $process_path_nm so that processes can be
#				run from different directories
#    02/02/05   Nick Iagallo    Added $Path when using 'nak'.
#    02/02/05   Nick Iagallo    Removed else statement from 'path setup' section.
#    06/04/04   Nick Iagallo    Added an input parameter to the warehouse
#				manager daily process
#    04/16/04   Nick Iagallo    Added an input parameter to a daily process
#				go_pe_generic and go_pe_client_generic.
#    04/02/04   Nick Iagallo    Added an input parameter to a daily process
#    03/25/04   Nick Iagallo    Added code to start the daily script 
#				go_pe_client_generic.
#    09/24/03   Nick Iagallo    Added an & when starting a workbook go_script
#    09/18/03   Nick Iagallo    Added the -w option to grep in monitor_jobs function
#    09/17/03   Nick Iagallo    Corrected ps statement in monitor_jobs function.
#    09/11/03   Nick Iagallo    Fixed the killing and monitoring of java
#				processes.
#    07/24/03   Nick Iagallo    Changed perl version being used
#    07/03/03   Nick Iagallo    Added code to the monitor_jobs function
#    07/03/03   Nick Iagallo    Corrected script name(go_workbook_generic.sh)
#    06/26/03   Nick Iagallo    Modified the monitoring and killing of
#				processes 
#    06/23/03   Nick Iagallo    Added code to start the daily script 
#				go_workbook_generic.csh
#    06/16/03   Nick Iagallo    Removed the code to not kill a job if it is
#                               currently processing a request.
#    05/19/03   Nick Iagallo    Added code to not kill a job if it is currently
#                               processing a request.
#    03/25/03   Nick Iagallo    Moved the OSR process under job type 'R'
#    03/25/03   Nick Iagallo    Added the ability to launch the OSR process
#    03/20/03   Ari Silverman   Removed ccms_path to everything besides go_pe_generic 
#    03/20/03   Ari Silverman   Added ccms_path to everything besides go_pe_generic 
#    03/18/03   Ari Silverman   Added ARGV[3] Path            
#    03/14/03   Ari Silverman   Added another Parm for FU,LU and SP
#    11/08/02   Nick Iagallo    created
#    11/18/02   Nick Iagallo    Added warehouse manager launch
#    11/21/02   Nick Iagallo    Added kill and cleanup processes
#    11/21/02   Nick Iagallo    Corrected kill bug
#    11/25/02   Nick Iagallo    Removed an input parameter when calling 
#				warehouse manager go_script
#    11/27/02   Nick Iagallo    Added an input parameter when calling
#				cleanup script
#    12/12/02   Nick Iagallo    Added a ccms return address to mailx
#    12/17/02   Nick Iagallo    In monitor_jobs function: tightened grep
#    01/21/03   Nick Iagallo    Changed if statement to look for pattern
#				"go_pe_generic"
#    01/27/03   Nick Iagallo    Added new type of daily process.
#    02/18/03   Nick Iagallo    Put daily process in background when
#				process is not a go_script
###########################################################################
# Job Types: D - Launch daily jobs
#            M - Monitor jobs
#            K - Kill daily jobs (NAK)
#            R - Launch reports
#            C - Launch cleanup script
#


use Sybase::DBlib;

#---------------
# Read arguments
#---------------
$central_server = @ARGV[0];
$job_type = @ARGV[1];
$debug_level = @ARGV[2];
$Path = @ARGV[3];

open(OUTFILE3,">$Path/echo_log.log");
#-----------
# Setup path
#-----------
print OUTFILE3 "Path<$Path>\n";
if($Path eq "") {
if (((getpwuid($<))[0]) eq 'ccms')
{
   $Path = "/usr/local/ccms/exe";
}
else
{
   $Path = ".";
}
}
print OUTFILE3 "Path 2<$Path>\n";
#----------------------------
# Setup central server handle
#----------------------------
$userC = (getpwuid($<))[0];
if($userC eq 'ccms')
{
   $exe_path = "/usr/local/ccms/security/exe";
   $pass_file = "/usr/local/ccms/security/dat/.PASSWORD_MATRIX";
   $lib_path = "/usr/local/ccms/lib";
}
else
{
$exe_path = "/ssb/cm/security/password/exe";
$pass_file = ".PASSWORD_MATRIX";
}

$userC = "ccms";
$ENV{"PW_MATRIX"}="$pass_file";
$ENV{"LD_LIBRARY_PATH"}="$lib_path";
print OUTFILE3 "PW_MATRIX=$pass_file\n";
print OUTFILE3 "LD_LIBRARY_PATH=$lib_path\n";
print OUTFILE3 "$central_server $userC\n";

$passwdC = `${exe_path}/pwEcho.exe $central_server $userC`;
$rc = $? ;
print OUTFILE3 "$passwdC\n";
if ($passwdC =~/^NA$/)
{
   print OUTFILE3 "This password is not available\n";
   exit -99;
}

close (OUTFILE3);

$sqlC = new Sybase::DBlib $userC, $passwdC, $central_server;

if ($job_type eq "D")
{
   
   # Retrieve and launch all daily jobs.
   #------------------------------------
   $query = "SELECT server_nm, ccms_path_nm, log_path_nm, process_nm,
                    task_typ_cd1, task_typ_cd2, app_db_nm, process_parm1,process_parm2,
                    process_parm3,process_parm4, process_path_nm
               FROM pe_admin..job_monitor
              WHERE job_typ = 'D'";
   #print STDOUT "$query\n";
   $sqlC->dbcmd("$query");
   $sqlC->dbsqlexec;
   $sqlC->dbresults;
   $row = 0;
   while(@dataC = $sqlC->dbnextrow(1))
   {
      $server[$row] = @dataC[1];
      $ccms_path[$row] = @dataC[3];
      $log_path[$row] = @dataC[5];
      $process_nm[$row] = @dataC[7];
      $task_type_cd1[$row] = @dataC[9];
      $task_type_cd2[$row] = @dataC[11];
      $app_db[$row] = @dataC[13];
      $param1[$row] = @dataC[15];
      $param2[$row] = @dataC[17];
      $param3[$row] = @dataC[19];
      $param4[$row] = @dataC[21];
      $process_path_nm[$row] = @dataC[23];
      $row++;
   }

   # Create log file
   open(OUTFILE2,">$Path/job_launch.log");

   for ($x = 0;$x < $row;$x++)
   {
      if ($process_nm[$x] =~ /^go_pe_generic/)
      {
         $cmd = "$process_path_nm[$x]/$process_nm[$x] $ccms_path[$x] $log_path[$x] $server[$x] $task_type_cd1[$x] $task_type_cd2[$x] $app_db[$x] $param1[$x] $param2[$x] $param3[$x] $param4[$x]";
      }
      elsif ($process_nm[$x] =~ /^go_pe_client_generic/)
      {
         $cmd = "$process_path_nm[$x]/$process_nm[$x] $ccms_path[$x] $log_path[$x] $server[$x] $task_type_cd1[$x] $task_type_cd2[$x] $app_db[$x] $param1[$x] $param2[$x] $param3[$x]";
      }
      elsif ($process_nm[$x] =~ /^go_pe_whm_generic/)
      {
         $cmd = "$process_path_nm[$x]/$process_nm[$x] $ccms_path[$x] $server[$x] $param1[$x]";
      }
      else
      {
         $cmd = "$process_path_nm[$x]/$process_nm[$x] $param1[$x] $param2[$x] $param3[$x] $param4[$x] &";
      }
      system($cmd);
      $runtime = localtime(time);
      print OUTFILE2 "Command:$runtime==>$cmd\n";
   }
   close (OUTFILE2);
}
elsif ($job_type eq "M")
{
   $outfile = "$Path/job_monitor.rpt";
   open(OUTFILE,">$outfile");
   $ret = &monitor_jobs;
   #---------------------------------------
   # email report to production support if
   # problems are found and generate alert.
   #---------------------------------------
   if ($ret)
   {
      close(OUTFILE);
      &email;
      exit -99;
   }
   close(OUTFILE);
}
elsif ($job_type eq "K")
{
   open(OUTFILE3,">$Path/job_kill.log");

   &Running_Processes;

   #-------------------------------------------
   # Retrieve processes that need to be killed.
   #-------------------------------------------
   $query = "SELECT server_nm, process_nm, task_typ_cd1, 
                    task_typ_cd2, process_parm1
               FROM pe_admin..job_monitor
              WHERE job_typ = 'K'";
   #print STDOUT "$query\n";
   $sqlC->dbcmd("$query");
   $sqlC->dbsqlexec;
   $sqlC->dbresults;
   $row = 0;
   while(@dataC = $sqlC->dbnextrow(1))
   {
      $server[$row] = @dataC[1];
      $process_nm[$row] = @dataC[3];
      $task_type_cd1[$row] = @dataC[5];
      $task_type_cd2[$row] = @dataC[7];
      $param1[$row] = @dataC[9];
      $row++;
   }

   for ($x = 0;$x < $row;$x++)
   {
      if ($param1[$x] =~ /pidfile/)
      {
         open(INFILE,"<$param1[$x]");
         $line = <INFILE>;
         close(INFILE);
         $cmd = "kill $line";
         system($cmd);
      }
      elsif (!($process_nm[$x] eq "pe_whm_srv.exe"))
      {
         $cmd = "$Path/nak -g $process_nm[$x] $server[$x] $task_type_cd1[$x] $param1[$x] -s 1 9 -a t -t 1 -f s";
         system($cmd);
      }
      else
      {
         $cmd = "$Path/nak -g $process_nm[$x] $server[$x] -s 15 9 -a t -t 1 -f s";
         system($cmd);
      }
      $runtime = localtime(time);
      print OUTFILE3 "$runtime==>Killed process:$process_nm[$x] task type:$task_type_cd1[$x] $param1[$x] Server:$server[$x]\n";
    }

   #------------------------------------------------
   # Reset calcs/reports back to 'Ready to Process'.
   #------------------------------------------------
   $query =  "UPDATE pe_report..sched_queue
                 SET queue_status_code = 'R'
                WHERE queue_status_code in ('A', 'W')";

   $sqlC->dbcmd("$query");
   $sqlC->dbsqlexec;
   $sqlC->dbresults;

   close (OUTFILE3);
}
elsif ($job_type eq "C")
{
   $cmd = "$Path/CleanLogFiles.pl $central_server $Path/";
   system($cmd);
}
elsif ($job_type eq "R")
{
   #------------------------------------
   # Retrieve and launch all report jobs.
   #------------------------------------
   $query = "SELECT server_nm, ccms_path_nm, log_path_nm, process_nm,
                    task_typ_cd1, task_typ_cd2, app_db_nm, process_parm1,process_parm2,
                    process_parm3,process_parm4
               FROM pe_admin..job_monitor
              WHERE job_typ = 'R'";
   #print STDOUT "$query\n";
   $sqlC->dbcmd("$query");
   $sqlC->dbsqlexec;
   $sqlC->dbresults;
   $row = 0;
   while(@dataC = $sqlC->dbnextrow(1))
   {
      $server[$row] = @dataC[1];
      $ccms_path[$row] = @dataC[3];
      $log_path[$row] = @dataC[5];
      $process_nm[$row] = @dataC[7];
      $task_type_cd1[$row] = @dataC[9];
      $task_type_cd2[$row] = @dataC[11];
      $app_db[$row] = @dataC[13];
      $param1[$row] = @dataC[15];
      $param2[$row] = @dataC[17];
      $param3[$row] = @dataC[19];
      $param4[$row] = @dataC[21];
      $row++;
   }

   # Create log file
   open(OUTFILE2,">$Path/job_report.log");

   for ($x = 0;$x < $row;$x++)
   {
      if ($process_nm[$x] =~ /^go_pe_osr/)
      {
         $cmd = "$Path/$process_nm[$x] $ccms_path[$x] $log_path[$x] $server[$x] $param2[$x] $param3[$x] $param1[$x]";
      }
      else
      {
         $cmd = "$Path[$x]/$process_nm[$x] $server[$x] &";
      }
      system($cmd);
      $runtime = localtime(time);
      print OUTFILE2 "Command:$runtime==>$cmd\n";
   }
   close (OUTFILE2);
}

exit 0;


sub monitor_jobs
{
   #----------------------------------------------------
   # Retrieve all jobs that should currently be running.
   #----------------------------------------------------
   $query = "SELECT server_nm, ccms_path_nm, log_path_nm, process_nm,
                    task_typ_cd1, task_typ_cd2, app_db_nm, process_parm1,
                    process_parm2,process_parm3,process_parm4
               FROM pe_admin..job_monitor
              WHERE job_typ = 'K'";
   #print STDOUT "$query\n";
   $sqlC->dbcmd("$query");
   $sqlC->dbsqlexec;
   $sqlC->dbresults;
   $row = 0;
   while(@dataC = $sqlC->dbnextrow(1))
   {
      $server[$row] = @dataC[1];
      $ccms_path[$row] = @dataC[3];
      $log_path[$row] = @dataC[5];
      $process_nm[$row] = @dataC[7];
      $task_type_cd1[$row] = @dataC[9];
      $task_type_cd2[$row] = @dataC[11];
      $app_db[$row] = @dataC[13];
      $param1[$row] = @dataC[15];
      $param2[$row] = @dataC[17];
      $param3[$row] = @dataC[19];
      $param4[$row] = @dataC[21];
      $row++;
   }

   $send_email = 0;
   for ($x = 0;$x < $row;$x++)
   {
      $process_found = 0;

      if ($param1[$x] =~ /pidfile/)
      {
         open(INFILE,"<$param1[$x]");
         $line = <INFILE>;
         chop($line);
         close(INFILE);
         $cmd = "ps -fade | grep -w $line";
      }
      elsif (length($param4[$x]) > 0)
      {
         open(INFILE,"<$param4[$x]");
         $line = <INFILE>;
         chop($line);
         close(INFILE);
         $cmd = "ps -fade | grep $line";
      }
      else
      {
         # Build ps command
         $cmd = "ps -fade" . " | grep $process_nm[$x]";

         $server[$x] =~ s/[ ]//g;
         if (length($server[$x]) > 0)
         {
            $cmd = $cmd . " | grep $server[$x]";
         }

         $task_type_cd1[$x] =~ s/[ ]//g;
         if (length($task_type_cd1[$x]) > 0)
         {
            $cmd = $cmd . " | grep C$task_type_cd1[$x]";
         }

         $param1[$x] =~ s/[ ]//g;
         if (length($param1[$x]) > 0)
         {
            $cmd = $cmd . " | grep $param1[$x]";
         }
      }   #else

      $cmd = $cmd . " | grep -v grep|";
      #print "$cmd\n";

      open (PROCESS,"$cmd");
      while ($inline=<PROCESS>)
      {
         $process_found++;
         print "PROCESS:$inline\n";
      }
      close (PROCESS);
      $runtime = localtime(time);
      if ($process_found > 1)
      {
         print OUTFILE "$runtime: Multiple processes running for $process_nm[$x] $task_type_cd1[$x] $param1[$x] for server $server[$x].\n";
         $send_email = 1;
      }
      elsif ($process_found < 1)
      {
         print OUTFILE "$runtime: Process $process_nm[$x] $task_type_cd1[$x] $param1[$x] not running for server $server[$x].\n";
         $send_email = 1;
      }

   }
   $send_email;
}

sub email
{
   #---------------------
   # Generate email list.
   #---------------------
   $query =  "SELECT email_addr
                FROM pe_report..rpt_assign
                WHERE report_name = 'Job Monitor'";

   #print "$query";
   $sqlC->dbcmd("$query");
   $sqlC->dbsqlexec;
   $sqlC->dbresults;
   while(@dataC = $sqlC->dbnextrow(1))
   {
      $email_list = $email_list . @dataC[1];
      $email_list = $email_list . ",";
   }
   chop($email_list);

   open(MESSAGE,"| mailx -r ccms\@statestreet.com -s \"Message From Job Monitor \" $email_list < $outfile");
   close(MESSAGE);
}

sub Running_Processes
{
   $processing_time = 0;
   while(1)
   {
      #--------------------------------------------------------
      # Change status so that calc/reports don't get processed.
      #--------------------------------------------------------
      $query =  "UPDATE pe_report..sched_queue
                    SET queue_status_code = 'W'
                  WHERE queue_status_code = 'R'";

      $sqlC->dbcmd("$query");
      $sqlC->dbsqlexec;
      $sqlC->dbresults;

      $query =  "SELECT count(*)
                   FROM pe_report..sched_queue
                  WHERE queue_status_code = 'A'";

      $sqlC->dbcmd("$query");
      $sqlC->dbsqlexec;
      $sqlC->dbresults;
      while(@dataC = $sqlC->dbnextrow(1))
      {
         $processing = @dataC[1];
      }

      if (($processing == 0) ||
          ($processing_time > 8))
      {
         last;
      }
      $processing_time++;
      sleep(900);
   }

}

