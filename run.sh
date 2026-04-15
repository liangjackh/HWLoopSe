#!/bin/bash

#git pull
find . -name '*.pyc' -delete && find . -name '__pycache__' -type d -exec rm -rf {} +

rm -f out.txt
#test_2
#python3 -m main 6 designs/test-designs/test_2.v --sv  --auto-plan --llm-provider deepseek --coi --strategy directed
#python3 -m main 7 designs/test-designs/test_2.v --sv --milestone-file milestones/test_2.json --coi --strategy directed

#or1200
#python3 -m main 60 or1200_subset.F --sv  --auto-plan --llm-provider deepseek --coi --strategy directed -t or1200_top
#python3 -m main 30 or1200_subset.F --sv  --auto-plan --milestone-file milestones/or1200_subset.json --coi --strategy directed -t or1200_top
#python3 -m main 30 or1200_subset.F --sv  --auto-plan --milestone-file milestones/or1200_p49.json --coi --strategy directed -t or1200_top

#sub-test
#python3 -m main 100 designs/test-designs/sub-test/sub.F --sv --auto-plan --llm-provider deepseek --coi --strategy directed -t top
#python3 -m main 6 designs/test-designs/sub-test/sub.F --sv --milestone-file milestones/sub-test.json --coi --strategy directed

#hack@dac18
#python3 -m main 30 hackdac18.F --sv --auto-plan --llm-provider deepseek --coi --strategy directed -t top_wrapper
#python3 -m main 30 hackdac18.F --sv  --auto-plan --milestone-file milestones/hackdac18/p1.json --coi --strategy directed -t top_wrapper
python3 -m main 30 hackdac18.F --sv  --auto-plan --milestone-file milestones/hackdac18/p2_fixed.json --coi --strategy directed -t top_wrapper



#python3 -m main 16 designs/test-designs/new_test/top_compat.sv --sv  -I designs/test-designs/new_test/include/ --auto-plan --llm-provider deepseek --coi --strategy directed
#python3 -m main 10 designs/test-designs/test_2.v --sv   --coi
#python3 -m main 1 or1200.F --sv --auto-plan --llm-provider deepseek
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
#python3 -m main 1 designs/benchmarks/or1200/or1200.F --sv -t or1200_top/home/ljh/haveFun/sybolicExecution/sylvia-related/siu/HWLoopSe/designs/test-designs/sub-test
