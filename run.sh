#!/bin/bash

#git pull
rm -f out.txt
python3 -m main 1 designs/test-designs/test_2.v --sv
#python3 -m main 1 filelist.F --sv
