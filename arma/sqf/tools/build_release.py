# coding=utf-8
#######################################################################
#							build.py						    	  #
#					 © 2018 Arcas Industries						  #
#					   All Rights Reserved							  #
#	 This script does require access to Mikero's MakePBO and		  #
#	 pboProject exececutables										  #
#######################################################################

DESTINATION_PATH = r"D:\A3Servers\Deployment\ESM"
MIKERO_PATH = r"C:\Program Files (x86)\Mikero\DePboTools\bin"

#######################################################################
#######################################################################
import os, subprocess, shutil, errno, psutil, sys, re, json
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
copy("{}\\ESM\\ESM\\bin\\Release\\ESM.dll".format(WORKING_DIR), "{}\\@ESM".format(WORKING_DIR))
copy("{}\\ESM\\ESM\\bin\\Release\\Newtonsoft.Json.dll".format(WORKING_DIR), "{}\\@ESM".format(WORKING_DIR))
copy("{}\\ESM\\ESM\\bin\\Release\\Maca134.Arma.Serializer.dll".format(WORKING_DIR), "{}\\@ESM".format(WORKING_DIR))
copy("{}\\ESM\\ESM\\bin\\Release\\websocket-sharp.dll".format(WORKING_DIR), "{}\\@ESM".format(WORKING_DIR))
copy("{}\\ESM\\ESM\\bin\\Release\\MySQL.Data.dll".format(WORKING_DIR), "{}\\@ESM".format(WORKING_DIR))
copy("{}\\ESM\\ESM\\bin\\Release\\INIFileParser.dll".format(WORKING_DIR), "{}\\@ESM".format(WORKING_DIR))
copy("{}\\ESM\\ESM\\bin\\Release\\NLog.dll".format(WORKING_DIR), "{}\\@ESM".format(WORKING_DIR))
#copy("{}\\ESM\\ESM\\bin\\Release\\esm-conf.ini".format(WORKING_DIR), "{}\\@ESM".format(WORKING_DIR))

# Copy over the directory
shutil.copytree("{}\\@ESM".format(WORKING_DIR), "{}\\@ESM".format(DESTINATION_PATH))

# PBO exile_server_manager
try:
	process = subprocess.check_output([
		"{}\\MakePBO.exe".format(MIKERO_PATH),
		"-NUP",
		"-@=exile_server_manager",
		"{}\\@ESM\\addons\\exile_server_manager".format(DESTINATION_PATH)
		], stderr=subprocess.STDOUT)

	process = subprocess.check_output([
		"{}\\MakePBO.exe".format(MIKERO_PATH),
		"-NUP",
		"-@=exile_server_overwrites",
		"{}\\@ESM\\addons\\exile_server_overwrites".format(DESTINATION_PATH)
		], stderr=subprocess.STDOUT)
except:
	print ("Failed to pbo {}".format(folderName))
	print (process.stdout)
	exit()

# Delete out the source
deleteDirectory("{}\\@ESM\\addons\\exile_server_manager".format(DESTINATION_PATH))
deleteDirectory("{}\\@ESM\\addons\\exile_server_overwrites".format(DESTINATION_PATH))

# Run Batch files for auto start
try:
	process = subprocess.Popen("Deploy_ESM.bat", cwd=r"D:\A3Servers", shell=True)
except:
	print ("Failed to start deployment")
	print (sys.exc_info()[0]);