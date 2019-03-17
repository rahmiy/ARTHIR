﻿<#
.SYNOPSIS
Get-LOG-MD_Hash_Baseline_Folder.ps1 creates a Hash_Baseline.txt of a folder
 - e.g. C:\Users
that you specify with the $ARTHIR_Baseline_Dir variable that can be used on other systems to exclude 
known good file hashes.  This can also be used to hash all files in the C:\Users directory 
and all subdirectories during an investigation. 

SHOUT OUT: Special thanks to Josh Rickard @MSAdministrator of http://letsautomate.it for 
his priceless assistance at the scheduled task function used in this module.

Use the following to record the modules applicability to the MITRE ATT&CK Framework

MITRE ATT&CK Technique IDs: TBD - LOTS of them

This script does depend on IMF Security's LOG-MD.exe, which is not
packaged with ARTHIR. You will have to purchase and download it from LOG-MD.com and
drop it in the .\Modules\bin\ directory. When you run ARTHIR.ps1, if you
add the -Pushbin switch at the command line, ARTHIR.ps1 will attempt to 
copy the LOG-MD.exe binary to each remote target's ADMIN$ share (C:\Windows)
and then move it to the directory specified with $ARTHIR_Dir.

If you want to remove the binary and/or reports from remote systems after it has run
use the cleanup module(s) or specify with the $DeleteReports and $DeleteAll variables.

Adjust the variables to what you want to do with each item:
  $ARTHIR_Dir_Task				Set to a directory for tool Tasks - needs short 8.3 name for Tasks
  $ARTHIR_Dir					Set to a directory you want the tool to be stored
  $ARTHIR_OutputDir_Task		Set to a directory for Tasks output - needs short 8.3 name for Tasks
  $ARTHIR_OutputDir				Set to a directory for reports
  $ARTHIR_ReportName			What to name the report.  Match this to DOWNLOAD
  $ARTHIR_Baseline_Dir			What folder do you want to hash the files for
  $Keep_Baseline				Will keep Hash_Baseline for future Hash Compares and rename it Hash_Keep_Baseline.txt
  $RenameReports 				Yes/No - Rename the reports to include the systemname or what you specify with $SysName variable
  $SysName						What you want each report to be pre-pended with such as "computername"
  $WriteEventLogEntry			Create an event log entry that this module ran 'Yes' or 'No'
  $EventSource					The name of the source the event will be written to the Application log (default is ARTHIR)
  $Event_ID						What event ID to use in the log entry
  
  BINDEP						The name of the binary/file you want to push to the remote systems
  DOWNLOAD						The name of the report you will copy back to the host or launching system, wildcards are acceptable
  
.NOTES
The BINDEP and DOWNLOAD directives are needed by ARTHIR.ps1 to determine where to find 
the binary to be used and how to handle output from this script.  
Use the wildcard * to capture the systemname in the report.
 - Example:  C:\Program Files\LMD\Results\*Report_AutoRuns*

BINDEP .\Modules\bin\Log-MD.exe
DOWNLOAD C:\Program Files\LMD\Results\*Hash_Baseline_*
#>
$Tool_Name = "LOG-MD.exe"
$ARTHIR_Dir_Task = "C:\Progra~1\LMD"
$ARTHIR_Dir = "C:\Program Files\LMD"
$ARTHIR_OutputDir_Task = "C:\Progra~1\LMD\Results"
$ARTHIR_OutputDir = "C:\Program Files\LMD\Results"
$ARTHIR_ReportName = "Hash_Baseline.txt"
#  Use 8.3 naming for folder names
$ARTHIR_Baseline_Dir = "C:\Dell"
$Keep_Baseline = "Yes"
$RenameReports = "Yes"
$SysName = $env:computername
# Does not currently work - The priority level of the task (0 highest - 10 lowest, 7 is default, 4-6 for interactive tasks)
$TaskPriorityLevel = 3
# The name of the scheduled task
$TaskName = "LOG-MD-Hash-Baseline-Test"
# Description of the scheduled task
$TaskDescr = "Run a LOG-MD Hash Baseline Task"
# Name of Tool used
$TaskCommand = "$Tool_Name"
# The Task Action command argument
$TaskArg = "-hb -hd $ARTHIR_Baseline_Dir"
# The time when the task starts, for demonstration purposes we run it 1 minute after we created the task
$TaskStartTime = [datetime]::Now.AddMinutes(1)
# Create event log entry
$WriteEventLogEntry = "Yes"
$EventSource = "ARTHIR"
$Event_ID = "1337"
#
#  Delete existing reports Hash_Baseline and $SysName-Hash_Baseline*
#
  Remove-Item -path $ARTHIR_OutputDir\*Hash_Baseline* -Force | Out-Null
#
#  Check to see if folder to hash exists
#
if (Test-Path $ARTHIR_Baseline_Dir) {
    Write-Output "$ARTHIR_Baseline_Dir already exists, baseline can continue" | out-file -filepath $ARTHIR_OutputDir\$SysName-Hash_Baseline_Status.txt
 } else {
    Write-Error "$ARTHIR_Baseline_Dir target folder does not exist"
    Break
    }
#
#  Delete existing reports Hash_Baseline and $SysName-Hash_Baseline*
#
  Remove-Item -Path $ARTHIR_Dir\Hash_Keep_Baseline_Folder.txt -Force | out-file -Append -filepath $ARTHIR_OutputDir\$SysName-Hash_Baseline_Status.txt
  Write-Output "Creating a temporary scheduled task for LOG-MD to run the Hash_Baseline feature" | out-file -Append -filepath $ARTHIR_OutputDir\$SysName-Hash_Baseline_Status.txt
#
#  Check for report folder existing, or create it
#
if (Test-Path $ARTHIR_OutputDir) {
    Write-Output "$ARTHIR_OutputDir already exists"
 } else {
    new-item $ARTHIR_OutputDir -itemtype directory
    }
#
#  Move uploaded tool to the destination directory from \Windows
#
Move-Item -Path "$env:SystemRoot\$Tool_Name" -Destination $ARTHIR_Dir -Force
#
#  Remove any existing $Tool_Name Task
#
$schedule = new-object -com("Schedule.Service") 
$schedule.connect() 
$tasks = $schedule.getfolder("\").gettasks(0)
$tasks | select Name | ? { $_.Name -eq $TaskName }
#$tasks.Settings.Priority = $TaskPriorityLevel
#
if ($tasks | select Name | ? { $_.Name -eq $TaskName }) {
    Write-Output "Checking for existing task and deleting it" | out-file -Append -filepath $ARTHIR_OutputDir\$SysName-Hash_Baseline_Status.txt
    SchTasks.exe /Delete /TN $TaskName /F | out-file -Append -filepath $ARTHIR_OutputDir\$SysName-Hash_Baseline_Status.txt
 } else {
    Write-Output " $TaskName - Task does not already exist on the system" | out-file -Append -filepath $ARTHIR_OutputDir\$SysName-Hash_Baseline_Status.txt
}
#
#  Create Hash Baseline Task to run LOG-MD
#
# attach the Task Scheduler com object
$service = new-object -ComObject("Schedule.Service")
$service.Connect()
$rootFolder = $service.GetFolder("\")
 
$TaskDefinition = $service.NewTask(0) 
$TaskDefinition.RegistrationInfo.Description = "$TaskDescr"
$TaskDefinition.Settings.Enabled = $true
$TaskDefinition.Settings.AllowDemandStart = $true
$TaskDefinition.Principal.RunLevel = 1
 
$triggers = $TaskDefinition.Triggers

$trigger = $triggers.Create(1) 
# Creates a "One time" trigger
$trigger.StartBoundary = $TaskStartTime.ToString("yyyy-MM-dd'T'HH:mm:ss")
$trigger.Enabled = $true
 
$Action = $TaskDefinition.Actions.Create(0)
$action.Path = "$TaskCommand"
$action.Arguments = "$TaskArg"
$action.WorkingDirectory = $ARTHIR_Dir_Task
 
$rootFolder.RegisterTaskDefinition("$TaskName",$TaskDefinition,6,"System",$null,5)
#
#  Run LOG-MD Hash Baseline Task
#
if (Test-Path $ARTHIR_Dir\$Tool_Name) {
    Write-Output "Starting Scheduled Task to run Hash Baseline" | out-file -Append -filepath $ARTHIR_OutputDir\$SysName-Hash_Baseline_Status.txt
    SchTasks.exe /Run /TN $TaskName | out-file -Append -filepath $ARTHIR_OutputDir\$SysName-Hash_Baseline_Status.txt
} else {
    Write-Error "$Tool_Name not found in $ARTHIR_Dir."
  Exit
  }
#
#  Loop thru and wait for Baseline to complete
#
Write-Output "Waiting for Hash_Baseline to be created..." | out-file -Append -filepath $ARTHIR_OutputDir\$SysName-Hash_Baseline_Status.txt
  while (!(Test-Path $ARTHIR_Dir\$ARTHIR_ReportName)) { Start-Sleep 10 }
#
#  Wait 10 seconds to allow closing of files
#
   Start-Sleep -s 10
#
# Check for output to exist
#  
if (Test-Path $ARTHIR_Dir\$ARTHIR_ReportName) {
    Write-Output "LOG-MD Created $ARTHIR_ReportName" | out-file -Append -filepath $ARTHIR_OutputDir\$SysName-Hash_Baseline_Status.txt
} else {
    Write-Error "LOG-MD failed to create $ARTHIR_ReportName" 
}
#
#  Rename files with $SysName
#
If ($RenameReports -eq 'No') {
  Write-Output "Reports not being renamed" | out-file -Append -filepath $ARTHIR_OutputDir\$SysName-Hash_Baseline_Status.txt
  }  
  else {
    Write-Output "Renaming and listing reports" | out-file -Append -filepath $ARTHIR_OutputDir\$SysName-Hash_Baseline_Status.txt
    Start-Sleep -s 60
    Move-Item -Path $ARTHIR_Dir\Hash_Baseline*.txt -Destination $ARTHIR_OutputDir
    Move-Item -Path $ARTHIR_Dir\Hash_Locked_Files* -Destination $ARTHIR_OutputDir
    Rename-Item -Path $ARTHIR_OutputDir\Hash_Locked_Files.csv -NewName $ARTHIR_OutputDir\$SysName-Hash_Baseline_Locked_Files.csv | out-file -Append -filepath $ARTHIR_OutputDir\$SysName-Hash_Baseline_Status.txt
    Rename-Item -Path $ARTHIR_OutputDir\$ARTHIR_ReportName -NewName $ARTHIR_OutputDir\$SysName-Hash_Baseline_Folder.txt | out-file -Append -filepath $ARTHIR_OutputDir\$SysName-Hash_Baseline_Status.txt
   }
#
#  Keep Hash_Baseline if wanted
#
If ($Keep_Baseline -eq 'No') {
    Write-Output " Not keeping $ARTHIR_Dir\$ARTHIR_ReportName baseline" | out-file -Append -filepath $ARTHIR_OutputDir\$SysName-Hash_Baseline_Status.txt
  } else {
    Copy-Item $ARTHIR_OutputDir\$SysName-Hash_Baseline_Folder.txt -Destination $ARTHIR_Dir\Hash_Keep_Baseline_Folder.txt | out-file -Append -filepath $ARTHIR_OutputDir\$SysName-Hash_Baseline_Status.txt
  }
#
#  Remove LOG-MD-Hash-Baseline Task
#
    Write-Output "Deleting completed task" | out-file -Append -filepath $ARTHIR_OutputDir\$SysName-Hash_Baseline_Status.txt
    SchTasks.exe /Delete /TN \$TaskName /F | out-file -Append -filepath $ARTHIR_OutputDir\$SysName-Hash_Baseline_Status.txt
#
#  Write log entry
#
If ($WriteEventLogEntry -eq 'No') {
  Write-Output "Skipping event log entry" | out-file -Append -filepath $ARTHIR_OutputDir\$SysName-Hash_Baseline_Status.txt
  Break
  }  
  elseif ([System.Diagnostics.EventLog]::SourceExists($EventSource) -eq $False) {
    New-EventLog -LogName Application -Source $EventSource
    Write-Output "Event log entry created" | out-file -Append -filepath $ARTHIR_OutputDir\$SysName-Hash_Baseline_Status.txt
    Write-EventLog -LogName Application -EntryType Information -EventId $Event_ID -Source $EventSource -Message 'LOG-MD Hash-Baseline Usersexecuted by Arthir'
 }
  else {
    Write-Output "Event log entry created" | out-file -Append -filepath $ARTHIR_OutputDir\$SysName-Hash_Baseline_Status.txt
    Write-EventLog -LogName Application -EntryType Information -EventId $Event_ID -Source $EventSource -Message 'LOG-MD Hash-Baseline Users executed by Arthir'
    }
  Write-Output "DONE - Hash Baseline creation completed" | out-file -Append -filepath $ARTHIR_OutputDir\$SysName-Hash_Baseline_Status.txt
  Get-ChildItem -Path "$ARTHIR_Dir\*Hash_*.txt" | out-file -Append -filepath $ARTHIR_OutputDir\$SysName-Hash_Baseline_Status.txt
  Get-ChildItem -Path "$ARTHIR_OutputDir\*Hash_*.txt" | out-file -Append -filepath $ARTHIR_OutputDir\$SysName-Hash_Baseline_Status.txt
# END