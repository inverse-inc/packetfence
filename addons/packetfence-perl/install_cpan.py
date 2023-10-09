import concurrent.futures
import csv 
from csv import DictReader
import subprocess
import time
import argparse
import sys
import os
import shutil
from itertools import islice
from collections import deque


class bcolors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'

def tail_to_stdout(file_path, num_lines=15) -> str:
    try:
        with open(file_path, 'r') as file:
            recent_lines = deque(file, num_lines)
            for line in recent_lines:
                print(line, end='')
    except FileNotFoundError:
        print("File not found")

#convert csv file to o list of dictionary
def convert_csv(csv_filename) -> list:
    list_of_depdencies = list()
    with open(csv_filename, 'r') as f:
        for line in csv.reader(f):
            if line != "":
                list_of_depdencies.append(dict(zip(("ModName","ModVersion","ModInstall","ModTest","ModNameClean","ModInstallRep"), line)))
    return list_of_depdencies


def manage_directory(root_path):
    directory_path = root_path + "/debian/install_perl_logs"
    if os.path.exists(directory_path) and os.path.isdir(directory_path):
        # If it exists, remove the entire directory to clear all old logs
        try:
            shutil.rmtree(directory_path)
        except Exception as e:
            print(f"Error removing {directory_path}: {e}")
    
    # Create the directory
    try:
        os.makedirs(directory_path)
    except Exception as e:
        print(f"Error creating {directory_path}: {e}")

    return directory_path

def convert_boolean(value) -> bool:
    default_value = True
    if value.strip().lower() in ['true', 'True']:
        default_value = True
    elif value.strip().lower() in ['false', 'False']:
        default_value = False
    return default_value

def install_perl_module(dict_data):
    file_name = f"logs_{dict_data['ModName']}.log"
    file_log = f"{logs_directory}/{file_name}"
    if convert_boolean(dict_data['ModTest']) == True:
        command=f"/usr/bin/cpan install {dict_data['ModInstall']}".split()
    elif convert_boolean(dict_data['ModTest']) == False:
        command=f"/usr/bin/cpan -T install {dict_data['ModInstall']}".split()
#        command=f"perl -MCPAN -e \"CPAN::Shell->notest('install','{dict_data['ModInstall']}')\"".split()
    print(f"Installing perl module: {dict_data['ModName']} \n" )
    with open(file_log, 'w') as f:
        try:
            process = subprocess.run(command,stdout=f,stderr=f,text=True, timeout=720)
        except subprocess.TimeoutExpired as e:
            print('Error, timeout expired: ', e)
            return 2, file_name
    return process.returncode, file_name


def paralle_execution(list_execute,max_iteration):
#    with concurrent.futures.ThreadPoolExecutor(max_workers=number_exec) as executor:
    with concurrent.futures.ProcessPoolExecutor(max_workers=number_exec) as executor:
        errors_install_perl = []
        list_module_perl_error = []
        # Start the load operations for eache entry from CSV file
        future_to_data = {executor.submit(install_perl_module, data): data for data in list_execute}
        for future in concurrent.futures.as_completed(future_to_data):
            data = future_to_data[future]
            response_data = future.result()
            return_code = response_data[0]
            log_file_name = response_data[1]
            if return_code != 0:
                if data.get('retry_install')  is None:
                    data['retry_install'] = 1
                elif data.get('retry_install')  is not None:
                    data['retry_install'] += 1
                list_module_perl_error.append(data)
                error_message = f"Error module installation: {data['ModName']} --> {data['ModInstall']}, more details please see the logs file: {log_file_name}, rc: {return_code} \n"
                print(bcolors.WARNING + error_message + bcolors.ENDC)
                #show last 15 lines for each error from log file
                print(bcolors.FAIL + f"ERROR(oputput from log): " + bcolors.ENDC)
                tail_to_stdout(f"{logs_directory}/{log_file_name}")
                if data.get('retry_install')  is not None and data['retry_install'] >= 6:
                    errors_install_perl.append(error_message) 
                
            else:
                print(f"{bcolors.OKGREEN} Perl module {data['ModName']} --> {data['ModInstall']} was successfull installed, rc: {return_code} {bcolors.ENDC}\n")

        if len(errors_install_perl) >= 1: 
            errors = "Next errors were found during installation: \n" + '\n'.join(errors_install_perl)
            sys.exit(bcolors.FAIL + errors + bcolors.ENDC)
        else:
            return list_module_perl_error


def find_installed_perl_modules():
    perl_script = '''
    #!/usr/bin/perl -w
    use ExtUtils::Installed;
    my $inst    = ExtUtils::Installed->new();
    my @modules = $inst->modules();
    foreach $module (@modules){
        print "$module," . $inst->version($module) . "\\n";
    }
    '''
    
    try:
        # Run the Perl script and capture its output
        output = subprocess.check_output(['perl', '-e', perl_script], universal_newlines=True)
        # Split the output into lines
        lines = output.strip().split('\n')
        # Split each line into module name and version
        perl_modules = [line.split(',') for line in lines]
        return [{"ModName": module[0], "ModVersion": module[1]} for module in perl_modules]
    except subprocess.CalledProcessError as e:
        print("Error running Perl script:", e)
        return []

def validate_installed_perl_module(original_list_of_depdencies, installed_perl_modules, modules_without_version):
    list_module_perl_error_installed = []
    for data_csv in original_list_of_depdencies:
        name_version_perl = dict(islice(data_csv.items(), 2))

        if name_version_perl not in installed_perl_modules:
            for data_installed in installed_perl_modules:
                if data_installed['ModName'].strip().lower() == data_csv['ModName'].strip().lower() and data_installed['ModName'] in modules_without_version and data_installed['ModVersion'] == '':
                    print(f"depedencies - {data_csv['ModName']} {data_csv['ModVersion']}; installed - {data_installed['ModName']} {data_installed['ModVersion']}  - {bcolors.OKBLUE} module without version {bcolors.ENDC}")
                    break
                elif data_installed['ModName'].strip().lower() == data_csv['ModName'].strip().lower() and data_installed['ModVersion'].strip().lower() != data_csv['ModVersion'].strip().lower():
                    print(f"depedencies - {data_csv['ModName']} {data_csv['ModVersion']}; installed - {data_installed['ModName']} {data_installed['ModVersion']}  - {bcolors.WARNING}version does not match{bcolors.ENDC}")
                    list_module_perl_error_installed.append(data_csv)
                    break

            else:
                print(f"{data_csv['ModName']} {data_csv['ModVersion']} -> {data_csv['ModInstall']}  - {bcolors.FAIL}was not installed{bcolors.ENDC}" )
                list_module_perl_error_installed.append(data_csv)
                continue

        else:
            print(f"{data_csv['ModName']} {data_csv['ModVersion']} - {bcolors.OKGREEN}was installed correctly{bcolors.ENDC}")
    return list_module_perl_error_installed

def install_dependencies(list_of_depdencies, max_iteration=6):
    for i in range(1,max_iteration+1):
        if len(list_of_depdencies) > 0:
            print(f"**************************{i} iteration instalation******************************")
            list_of_depdencies = paralle_execution(list_of_depdencies,max_iteration)

def validate_dependencies(original_list_of_depdencies,modules_without_version):
    print(f"**************************1 iteration validate******************************")
    installed_perl_modules = find_installed_perl_modules()
    ts = validate_installed_perl_module(original_list_of_depdencies, installed_perl_modules,modules_without_version)
    for i in range(2,7):
        if len(ts) > 0:
            print(f"**************************{i} iteration validate******************************")
#            paralle_execution(ts)
            install_dependencies(ts,max_iteration=3)
            installed_perl_modules = find_installed_perl_modules()
            ts = validate_installed_perl_module(original_list_of_depdencies, installed_perl_modules,modules_without_version)
        else:
            break
        if i >= 6:
            sys.exit(bcolors.FAIL + "Validate perl modules failed, please see above errors" + bcolors.ENDC)

def write_modules_installed_file(filename):
    directory_path = os.environ.get('BASE_DIR', '/usr/local/pf/lib/perl_modules')
    installed_perl_modules = find_installed_perl_modules()
    with open(directory_path + '/' + filename, 'x') as f:
        for module in installed_perl_modules:
            f.write(f"{module['ModName']},{module['ModVersion']}\n")

if __name__ == '__main__':
    # construct the argument parse and parse the arguments
    cpu_count = os.cpu_count()
    number_exec = round(cpu_count * 1.5 + 0.1)
    parser = argparse.ArgumentParser()
    parser.add_argument("-df", "--dependencies_csv_file", required=True,  help="depedencies file's path")
    parser.add_argument("-mw", "--max_workers", required=False, help="The number of Perl modules to be installed simultaneously, number cpu multiplied by 1.5", default = number_exec,type=int)
    parser.add_argument("-vi", "--validate_perl_module", required=False, help="validate perl module", default = False, type= bool)
    
    args = parser.parse_args()
    csv_filename = args.dependencies_csv_file
    number_exec = args.max_workers
    validate_perl_module = args.validate_perl_module

    modules_without_version=("Net::Radius" "libwww::perl" "Module::Loaded")
    list_of_depdencies = convert_csv(csv_filename)
    original_list_of_depdencies = list_of_depdencies
    logs_directory = manage_directory(os.environ.get('OUTPUT_DIRECTORY', '/mnt/output'))
    
    if validate_perl_module: 
        validate_dependencies(original_list_of_depdencies,modules_without_version)
    else:
        install_dependencies(list_of_depdencies)
        validate_dependencies(original_list_of_depdencies,modules_without_version)
        write_modules_installed_file('modules_installed.csv')
