import concurrent.futures
#import urllib.request
import csv 
from csv import DictReader
import subprocess
import time
import argparse
import sys
import os
import shutil

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
    root_path = os.getcwd()
    directory_path = root_path + "/install_perl"
    if os.path.exists(directory_path) and os.path.isdir(directory_path):
        # If it exists, remove the entire directory
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
    result = status_execution(process, dict_data)
    return result, file_name
    

#ts = install_perl_module(list_of_depdencies[0])



def paralle_execution(list_execute):
    #with concurrent.futures.ThreadPoolExecutor(max_workers=number_exec) as executor:
    with concurrent.futures.ProcessPoolExecutor(max_workers=number_exec) as executor:
        errors_install_perl = []
        list_module_perl_eror = []
        # Start the load operations and mark each future with its URL
        future_to_url = {executor.submit(install_perl_module, url): url for url in list_execute}
        for future in concurrent.futures.as_completed(future_to_url):
            url = future_to_url[future]
            data = future.result()
            if data[0] != 0:
                if url.get('retry')  is None:
                    url['retry'] = 1
                elif url.get('retry')  is not None:
                    url['retry'] += 1
                list_module_perl_eror.append(url)
                error_message = f"Error module installation: {url['a']} --> {url['c']}, more details please see the logs file: {data[1]}, rc: {data[0]} \n"
                print(bcolors.WARNING + error_message + bcolors.ENDC)
                if url.get('retry')  is not None and url['retry'] >= 6:
                    errors_install_perl.append(error_message) 
                
            else:
                print(f"{bcolors.OKGREEN} Perl module {url['a']} --> {url['c']} was successfull installed, rc: {data[0]} {bcolors.ENDC}\n")

        if len(errors_install_perl) >= 1: 
            errors = "Next errors were found during installation: \n" + '\n'.join(errors_install_perl)
            sys.exit(bcolors.FAIL + errors + bcolors.ENDC)
        else:
            return list_module_perl_eror


if __name__ == '__main__':
    # construct the argument parse and parse the arguments
    parser = argparse.ArgumentParser()
    parser.add_argument("-d", "--dependencies", required=True,	help="file's name")
    parser.add_argument("-mw", "--max_workers", required=False,	help="number of perl module installation simultany, default is 30", default = 30)
    args = parser.parse_args()

    filename = args.dependencies
    number_exec = args.max_workers

    list_of_depdencies = list()
    with open(filename, 'r') as f:
        for line in csv.reader(f):
            list_of_depdencies.append(dict(zip(("a","b","c","d","e","f"), line)))

    logs_directory = manage_directory()
    
    for i in range(1,7):
        print(f"**************************{i} iteration******************************")
        if len(list_of_depdencies) > 0:
            list_of_depdencies = paralle_execution(list_of_depdencies)