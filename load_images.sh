#!/bin/bash

####先从docker hub下载，再打tag

file="images.properties"

if [ -f "$file" ]
then
  echo "$file found."

  while IFS='=' read -r key value
  do
    echo "=========================="
    echo "下载${value},换标签为:${key}"
    docker pull ${value}
    docker tag ${value} ${key}
    docker rmi ${value}
  done < "$file"

else
  echo "$file not found."
fi

