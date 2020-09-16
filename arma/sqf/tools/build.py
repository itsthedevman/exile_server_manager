# coding=utf-8
#######################################################################
#							build.py						    	  #
#					 © 2018 Arcas Industries						  #
#					   All Rights Reserved							  #
#	 This script does require access to Mikero's MakePBO and		  #
#	 pboProject exececutables										  #
#######################################################################

DESTINATION_PATH = r"D:\ArmaServers\Deployment\ESM"
MIKERO_PATH = r"C:\Program Files (x86)\Mikero\DePboTools\bin"
PBOS = [
	"exile_server_manager",
	"exile_server_overwrites",
	"exile_server_xm8",
	"exile_server_hacking",
	"exile_server_grinding",
	"exile_server_charge_plant_started",
	"exile_server_flag_steal_started",
	"exile_server_player_connected"
]

#######################################################################
#######################################################################
import os, subprocess, shutil, errno, psutil, sys, re, json, datetime
#######################################################################
def deleteDirectory(path):
	if os.path.exists(path):
		shutil.rmtree(path)

#######################################################################
def copy(src, dst):
	try:
		if os.path.isdir(src):
			shutil.copytree(src, dst)
		else:
			shutil.copy(src, dst)
	except WindowsError as exc:
		print (exc)

#######################################################################
def killProcess(process):
	for proc in psutil.process_iter():
		if proc.name() == process:
			proc.kill()

#######################################################################
#######################################################################
#######################################################################

WORKING_DIR = os.path.dirname(os.path.realpath(__file__))

# Kill Arma
killProcess("arma3server.exe")

# Delete the directory
deleteDirectory("{}\\@ESM".format(DESTINATION_PATH))

# Copy over the DLLs
copy("{}\\ESM\\ESM\\bin\\Debug\\ESM.dll".format(WORKING_DIR), "{}\\@ESM".format(WORKING_DIR))

# Copy over the directory
shutil.copytree("{}\\@ESM".format(WORKING_DIR), "{}\\@ESM".format(DESTINATION_PATH))

# PBO exile_server_manager
try:
	for mod in PBOS:
		process = subprocess.check_output([
			"{}\\MakePBO.exe".format(MIKERO_PATH),
			"-NUP",
			"-@={}".format(mod),
			"{}\\@ESM\\addons\\{}".format(DESTINATION_PATH, mod)
			], stderr=subprocess.STDOUT)
except:
	print ("Failed to pbo {}".format(mod))
	print (process.stdout)
	exit()

# Delete out the source
for mod in PBOS:
	deleteDirectory("{}\\@ESM\\addons\\{}".format(DESTINATION_PATH, mod))

# Copy over the fake logs
now = datetime.datetime.now()
year = now.year
month = now.month
day = now.day

if not os.path.isdir(f"{DESTINATION_PATH}\\@ExileServer\\extDB\\logs\\{year}\\{month}\\{day}"):
	os.makedirs(f"{DESTINATION_PATH}\\@ExileServer\\extDB\\logs\\{year}\\{month}\\{day}")

copy(f"{WORKING_DIR}\\data\\Exile_DeathLog.log", f"{DESTINATION_PATH}\\@ExileServer\\extDB\\logs\\{year}\\{month}\\{day}")
copy(f"{WORKING_DIR}\\data\\Exile_TerritoryLog.log", f"{DESTINATION_PATH}\\@ExileServer\\extDB\\logs\\{year}\\{month}\\{day}")
copy(f"{WORKING_DIR}\\data\\Exile_TradingLog.log", f"{DESTINATION_PATH}\\@ExileServer\\extDB\\logs\\{year}\\{month}\\{day}")

# Run Batch files for auto start
try:
	process = subprocess.Popen("Deploy_ESM.bat", cwd=r"D:\ArmaServers", shell=True)
except:
	print ("Failed to start deployment")
	print (sys.exc_info()[0]);
