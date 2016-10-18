This folder contains helper scripts to put in place monitoring "best practices", using "Monit" watchdog. Feel free to edit.

 * monit_build_configuration.pl file: Perl script that will put in place "Monit" configuration files depending on arguments. Running it without any parameters will provide you the appropriate syntax to use.

 * .tt files: Template Toolkit files used as templates by the 'monit_build_configuration.pl' Perl script to generate "Monit" configuration files.

 * monitoring-scripts folder: Helpers used to maintain a list of check scripts that ensures OS best-practices.

 * oom_immunize_process_names folder: Helpers used by a "Monit" check to immunize some critical processes from OOM.
