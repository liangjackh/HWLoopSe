#!/bin/bash

#git pull
rm -f out.txt
#python3 -m main 1 designs/test-designs/test_2.v --sv
#python3 -m main 1 filelist.F --sv
#for file in $(ls designs/test-designs/)
#do
#    echo "================== Testing $file ==================" >> out.txt
#    python3 -m main 1 designs/test-designs/$file --sv >> out.txt
#done

#python3 -m main 1 designs/test-designs/ACW.v --sv # 模块缺失，无法解析
#python3 -m main 1 designs/test-designs/non-pipelined-microprocessor.v --sv
python3 -m main 1 designs/test-designs/comb_loop.F --sv
#python3 -m main 1 designs/test-designs/daio.v --sv
#python3 -m main 1 designs/test-designs/mini_daio.v --sv