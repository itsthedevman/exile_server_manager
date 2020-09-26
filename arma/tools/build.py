# coding=utf-8
#######################################################################
#							build.py						    	  #
#					 © 2018 Arcas Industries						  #
#					   All Rights Reserved							  #
#	 This script does require access to Mikero's MakePBO and		  #
#	 pboProject exececutables										  #
#######################################################################

DESTINATION_PATH = r"E:\ArmaServers\Deployment\ESM"
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
from pathlib import Path
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
		try:
			if proc.name().lower() == process.lower():
				proc.kill()
				return True
		except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
			return False


#######################################################################
#######################################################################
#######################################################################

GIT_DIR = Path(os.path.abspath(__file__)).parents[2]
SQF_DIR = "{}\\sqf".format(GIT_DIR)
EXTENSION_DIR = "{}\\extension".format(GIT_DIR)

# Kill Arma
killProcess("arma3server.exe")

# Delete the directory
deleteDirectory("{}\\@ESM".format(DESTINATION_PATH))

# Copy over the DLLs
copy("{}\\esm.dll".format(EXTENSION_DIR), "{}\\@ESM".format(SQF_DIR))

# Copy over the directory
shutil.copytree("{}\\@ESM".format(SQF_DIR), "{}\\@ESM".format(DESTINATION_PATH))

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

# # Copy over the fake logs
# now = datetime.datetime.now()
# year = now.year
# month = now.month
# day = now.day

# if not os.path.isdir(f"{DESTINATION_PATH}\\@ExileServer\\extDB\\logs\\{year}\\{month}\\{day}"):
# 	os.makedirs(f"{DESTINATION_PATH}\\@ExileServer\\extDB\\logs\\{year}\\{month}\\{day}")

# copy(f"{SQF_DIR}\\tools\\data\\Exile_DeathLog.log", f"{DESTINATION_PATH}\\@ExileServer\\extDB\\logs\\{year}\\{month}\\{day}")
# copy(f"{SQF_DIR}\\tools\\data\\Exile_TerritoryLog.log", f"{DESTINATION_PATH}\\@ExileServer\\extDB\\logs\\{year}\\{month}\\{day}")
# copy(f"{SQF_DIR}\\tools\\data\\Exile_TradingLog.log", f"{DESTINATION_PATH}\\@ExileServer\\extDB\\logs\\{year}\\{month}\\{day}")

# Run Batch files for auto start
try:
	process = subprocess.Popen("Deploy_ESM.bat", cwd=r"D:\ArmaServers", shell=True)
except:
	print ("Failed to start deployment")
	print (sys.exc_info()[0]);
