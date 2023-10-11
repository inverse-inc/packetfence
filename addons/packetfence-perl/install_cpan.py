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


def manage_directory():
    root_path = os.environ.get('OUTPUT_DIRECTORY', '/mnt/output')
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

def convert_boolean(value):
    default_value = True
    if value.strip().lower() in ['true', 'True']:
        default_value = True
    elif value.strip().lower() in ['false', 'False']:
        default_value = False
    return default_value

def status_execution(process_ts, data_line):
    while True:
        # Do something else
        return_code = process_ts.poll()
#        print(f"Waiting for installation module perl: {data_line['a']} --> {data_line['c']} \n")
        time.sleep(5)
        if return_code is not None:
            # print("***********************")
            # # Process has finished, read rest of the output
            # if return_code != 0:
            #     print(f"error {data_line['a']}:  {return_code}")
            #     break
            # print(f"Perl module {data_line['a']}  was successfull installed, return code: {return_code}")
            # print("***********************")
            break
            
    return return_code



def install_perl_module(dict_data):
    file_name = f"logs_{dict_data['a']}.log"
    file_log = f"{logs_directory}/{file_name}"
    if convert_boolean(dict_data['d']) == True:
        command=f"/usr/bin/cpan install {dict_data['c']}".split()
    elif convert_boolean(dict_data['d']) == False:
        command=f"/usr/bin/cpan -T install {dict_data['c']}".split()
#        command=f"perl -MCPAN -e \"CPAN::Shell->notest('install','{dict_data['c']}')\"".split()
#    process = subprocess.Popen(command, stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    print(f"Installing perl module: {dict_data['a']} \n" )
    with open(file_log, 'w') as f:
#        process = subprocess.Popen(command, stdout=f,stderr=f,text=True)
        process = subprocess.Popen(command, stdout=f,stderr=f,text=True)
    result_status_execution = status_execution(process, dict_data)
    return result_status_execution, file_name


def paralle_execution(list_execute):
    #with concurrent.futures.ThreadPoolExecutor(max_workers=number_exec) as executor:
    with concurrent.futures.ProcessPoolExecutor(max_workers=number_exec) as executor:
        errors_install_perl = []
        list_module_perl_error = []
        # Start the load operations and mark each future with its URL
        future_to_url = {executor.submit(install_perl_module, url): url for url in list_execute}
        for future in concurrent.futures.as_completed(future_to_url):
            url = future_to_url[future]
            data = future.result()
            return_code = data[0]
            log_file_name = data[1]
            if return_code != 0:
                if url.get('retry_install')  is None:
                    url['retry_install'] = 1
                elif url.get('retry_install')  is not None:
                    url['retry_install'] += 1
                list_module_perl_error.append(url)
                error_message = f"Error module installation: {url['a']} --> {url['c']}, more details please see the logs file: {log_file_name}, rc: {return_code} \n"
                print(bcolors.WARNING + error_message + bcolors.ENDC)
                if url.get('retry_install')  is not None and url['retry_install'] >= 6:
                    errors_install_perl.append(error_message) 
                
            else:
                print(f"{bcolors.OKGREEN} Perl module {url['a']} --> {url['c']} was successfull installed, rc: {return_code} {bcolors.ENDC}\n")

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
#        return [{"module_name": module[0], "module_version": module[1]} for module in perl_modules]
        return [{"a": module[0], "b": module[1]} for module in perl_modules]
    except subprocess.CalledProcessError as e:
        print("Error running Perl script:", e)
        return []

def validate_installed_perl_module(original_list_of_depdencies, installed_perl_modules,modules_without_version):
    list_module_perl_error_installed = []
    for data_csv in original_list_of_depdencies:
        name_version_perl = dict(islice(data_csv.items(), 2))

        if name_version_perl not in installed_perl_modules:
            for data_installed in installed_perl_modules:
                if data_installed['a'].strip().lower() == data_csv['a'].strip().lower() and data_installed['a'] in modules_without_version and data_installed['b'] == '':
                    print(f"depedencies - {data_csv['a']} {data_csv['b']}; installed - {data_installed['a']} {data_installed['b']}  - {bcolors.OKBLUE} module without version {bcolors.ENDC}")
                    break
                elif data_installed['a'].strip().lower() == data_csv['a'].strip().lower() and data_installed['b'].strip().lower() != data_csv['b'].strip().lower():
                    print(f"depedencies - {data_csv['a']} {data_csv['b']}; installed - {data_installed['a']} {data_installed['b']}  - {bcolors.WARNING}version does not match{bcolors.ENDC}")
                    list_module_perl_error_installed.append(data_csv)
                    break

            else:
                print(f"{data_csv['a']} {data_csv['b']} -> {data_csv['c']}  - {bcolors.FAIL}was not installed{bcolors.ENDC}" )
                list_module_perl_error_installed.append(data_csv)
                continue

        else:
            print(f"{data_csv['a']} {data_csv['b']} - {bcolors.OKGREEN}was installed correctly{bcolors.ENDC}")
    return list_module_perl_error_installed


if __name__ == '__main__':
    # construct the argument parse and parse the arguments
    parser = argparse.ArgumentParser()
    parser.add_argument("-d", "--dependencies", required=True,  help="depedencies file's path")
    parser.add_argument("-mw", "--max_workers", required=False, help="The number of Perl modules to be installed simultaneously, default is 30", default = 30)
    args = parser.parse_args()

    filename = args.dependencies
    number_exec = args.max_workers
    modules_without_version=("Net::Radius" "libwww::perl" "Module::Loaded")

    list_of_depdencies = list()
    with open(filename, 'r') as f:
        for line in csv.reader(f):
            list_of_depdencies.append(dict(zip(("a","b","c","d","e","f"), line)))

    original_list_of_depdencies = list_of_depdencies

    logs_directory = manage_directory()
    
    for i in range(1,7):
        if len(list_of_depdencies) > 0:
            print(f"**************************{i} iteration instalation******************************")
            list_of_depdencies = paralle_execution(list_of_depdencies)



    print(f"**************************1 iteration validate******************************")
    installed_perl_modules = find_installed_perl_modules()
    ts = validate_installed_perl_module(original_list_of_depdencies, installed_perl_modules,modules_without_version)
    for i in range(2,7):
        if len(ts) > 0:
            print(f"**************************{i} iteration validate******************************")
            paralle_execution(ts)
            installed_perl_modules = find_installed_perl_modules()
            ts = validate_installed_perl_module(original_list_of_depdencies, installed_perl_modules,modules_without_version)
        else:
            break
        if i >= 6:
            sys.exit(bcolors.FAIL + "Validate perl modules failed, please see above errors" + bcolors.ENDC)