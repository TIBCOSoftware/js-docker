echo off

set bundledAntPath=.\apache-ant

set ANT_HOME=%bundledAntPath%
set PATH=%ANT_HOME%\bin;%PATH%
set ANT_RUN=%ANT_HOME%\bin\ant.bat


REM Collect the command line args

set DROP_FIRST=%0

set CMD_LINE_ARGS=
:setArgs
if ""%1""=="""" goto doneSetArgs
set CMD_LINE_ARGS=%CMD_LINE_ARGS% %1
shift
goto :setArgs
:doneSetArgs

%ANT_RUN% -nouserlib -f buildWARFileInstaller.xml %CMD_LINE_ARGS%
