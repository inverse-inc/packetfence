#!/usr/bin/env python
import concurrent.futures
import argparse
import subprocess
import time
import sys

def status_execution(process_ts, image):
    while True:
        return_code = process_ts.poll()
#        print(f"Wait next docker image to be created: {image}")
        time.sleep(5)
        if return_code is not None:
            break
    return return_code

def docker_build(image):
    command=f"/bin/bash {script_path} {image}".split()
    file_log = f"/var/log/docker_build_image/{image}.log"
    print(f"Build image {image} \n")
    with open(file_log, 'w') as f:
        process = subprocess.Popen(command, stdout=f,stderr=f,text=True)
    result_status_execution = status_execution(process, image)
    return result_status_execution

def parallel_execution(list_execute):
    with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
#    with concurrent.futures.ProcessPoolExecutor(max_workers=10) as executor:
        # Start the load operations for eache entry from CSV file
        future_to_docker = {executor.submit(docker_build, image_name): image_name for image_name in list_execute}
        for future in concurrent.futures.as_completed(future_to_docker):
            image_name = future_to_docker[future]
            response_data = future.result()
            return_code = response_data
            if return_code != 0:
                message = f"bad : { image_name }, {response_data}, {return_code}"
                print(message)
                sys.exit(message)
            else:
                print(f"good : { image_name }, {response_data}, {return_code}")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("-sp", "--scriptpath", required=True,  help="script path of execution")
    parser.add_argument("-im", "--image", nargs='+')
    args = parser.parse_args()
    images_name = list(filter(None, args.image[0].split()))
    global script_path
    script_path = args.scriptpath

    parallel_execution(images_name)

if __name__ == '__main__':
    main()
