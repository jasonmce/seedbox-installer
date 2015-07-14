swarm-builder
=============

Script to install basic services for a seed box on Ubuntu 14.04 LTS
Probably works on 12.04 LTS.

To run:
Set any default values you want to change in the environment and go.
For example, to set SSH to listen on port 2222 you could
$ export SSH_PORT=2222
$ ./seedbox-installer.sh
and it would use the SSH_PORT value in the environment rather than the default 22 in the script.
