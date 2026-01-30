#!/bin/bash

#git pull
rm -f out.txt
#python3 -m main 2 designs/test-designs/test_2.v --sv -t place_holder_2
python3 -m main 3 designs/test-designs/test_2.v --sv 
#python3 -m main 2 designs/aes/aes.F --sv 
#python3 -m main 2 designs/test-designs/updowncounter.v --sv 
#python3 -m main 1 filelist.F --sv
#for file in $(ls designs/test-designs/)
#do
#    echo "================== Testing $file ==================" >> out.txt
#    python3 -m main 1 designs/test-designs/$file --sv >> out.txt
#done

#python3 -m main 1 designs/test-designs/ACW.v --sv # 模块缺失，无法解析
#python3 -m main 1 designs/test-designs/non-pipelined-microprocessor.v --sv
#python3 -m main 1 designs/test-designs/comb_loop.F --sv
#python3 -m main 1 designs/test-designs/daio.v --sv
#python3 -m main 1 designs/test-designs/mini_daio.v --sv
#python3 -m main 1 designs/test-designs/picorv/picorv32.v --sv
#python3 -m main 1 designs/picorv32.v --sv
#python3 -m main 1 designs/benchmarks/or1200/or1200.F --sv -t or1200_top