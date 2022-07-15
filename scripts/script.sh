#!/bin/bash

path="{key_path}"

if [[-f $path == "simpleserverkey"]]
then
   echo "key is already present"
else
  echo "adding sshkey"
  ssh-keyscan ${hostip} >> /root/.ssh/known_hosts
