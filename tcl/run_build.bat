@echo off
setlocal EnableDelayedExpansion

:: =====================================================================================
:: Color codes for the console
:: =====================================================================================
for /f %%a in ('powershell -NoProfile -Command "[char]27"') do set "ESC=%%a"
set "RED=%ESC%[91m"
set "GREEN=%ESC%[92m"
set "YELLOW=%ESC%[93m"
set "RESET=%ESC%[0m"

:: =====================================================================================
:: Check for help call
:: =====================================================================================
if "%~1" == "" goto display_help
if "%~1" == "--help" goto display_help

:: =====================================================================================
:: The first argument is the path
:: =====================================================================================
set "BUILD_DIR=%~1"
set "PROJECT_NAME=FIFO_sync"
set "TOP_ENTITY=FIFO"

:: =====================================================================================
:: Start build tcl-script with input arguments
:: =====================================================================================
echo %YELLOW%[INFO] Starting the project build...%RESET%
echo %YELLOW%[INFO] Target directory: %BUILD_DIR%%RESET%

quartus_sh.exe -t build.tcl %*

if %ERRORLEVEL% equ 0 (
	echo %GREEN%[SUCCESS] The project has been successfully built.%RESET%
) else (
	echo %RED%[ERROR] An error occurred during the build.%RESET%
	pause
	exit /b 1
)

:: =====================================================================================
:: Start STA tcl-script with input arguments
:: =====================================================================================
quartus_sta -t timing.tcl "%BUILD_DIR%"
if %ERRORLEVEL% equ 0 (
	echo %GREEN%[SUCCESS] STA completed successfully.%RESET%
) else (
	echo %RED%[ERROR] STA completed with errors.%RESET%
	pause
	exit /b 1
)

:: =====================================================================================
:: Start of simulation
:: =====================================================================================
set "MODELSIM="
set "SIM_BUILD_DIR=%BUILD_DIR:\=/%"
set "REST_ARGS="
for /f "tokens=1,* delims= " %%a in ("%*") do set "REST_ARGS=%%b"
set "SIM_TCL_PATH=%~dp0sim.tcl"
set "SIM_TCL_PATH=%SIM_TCL_PATH:\=/%"

vsim -c -do "set argv {%SIM_BUILD_DIR% %REST_ARGS%}; set argc [llength $argv]; source {%SIM_TCL_PATH%}; quit -f"
if %ERRORLEVEL% equ 0 (
	echo [SUCCESS] Simulation completed successfully!
) else (
	echo [ERROR] Simulation completed with errors.
	pause
	exit /b 1
)	

pause
exit /b 0

:: =====================================================================================
:: Help output function
:: =====================================================================================
:display_help
echo %YELLOW%=======================================================================================
echo                                Project Build Script Help
echo =======================================================================================
echo.
echo Using the command:
echo 	run_build.bat ^<build_path^> [parameter_flags]
echo.
echo Available parameter flags:
echo 	-DATA_WIDTH ^<value^>		Input and output data width
echo 	-ADDR_WIDTH ^<value^>		Address width
echo 	-ALMOST_FULL_VAL ^<value^>	Almost full threshold
echo 	-ALMOST_EMPTY_VAL ^<value^>	Almost empty threshold
echo 	-MEM_STYLE ^<string^>		Memory type: `"logic"` - flip-flops, 
echo						`"M9K"` - block RAM of MAX10
echo.
echo Note:
echo 	All unspecified parameters will take the default values specified in the HDL.
echo.
echo Call examples:
echo 	run_build.bat ./build_out
echo		run_build.bat ^<build_path^> -DATA_WIDTH 8 -ADDR_WIDTH 4 -ALMOST_FULL_VAL 14 
echo -ALMOST_EMPTY_VAL 2 -MEM_STYLE "M9K"
echo =======================================================================================%RESET%
pause
exit /b 0