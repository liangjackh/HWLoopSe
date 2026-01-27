"""This file is the entrypoint of the execution."""
from __future__ import absolute_import
from __future__ import print_function
import z3
from z3 import Solver, Int, BitVec, Context, BitVecSort, ExprRef, BitVecRef, If, BitVecVal, And
import sys
import os
from optparse import OptionParser
from typing import Optional
import random, string
import time
from itertools import product
import logging
import gc
from engine.execution_manager import ExecutionManager
from engine.symbolic_state import SymbolicState
from helpers.rvalue_parser import tokenize, parse_tokens, evaluate
from engine.execution_engine import ExecutionEngine
import pyslang as ps
from helpers.slang_helpers import SlangSymbolVisitor, SymbolicDFS
# SlangNodeVisitor removed 
import redis
import threading
import time

from helpers.rvalue_to_z3 import parse_expr_to_Z3

gc.collect()

with open('errors.log', 'w'):
    pass
logging.basicConfig(filename='errors.log', level=logging.DEBUG)
logging.debug("Starting over")


INFO = "Verilog Symbolic Execution Engine"
USAGE = "Usage: python3 -m main <num_cycles> <verilog_file>.v > out.txt"
    
def timeout_exit():
    """This only happens when the timer runs out."""
    print("Execution time limit exceeded. Exiting.")
    sys.exit(1)

def showVersion():
    print(INFO)
    print(USAGE)
    sys.exit()
    
def main():
    """Entrypoint of the program."""
    engine: ExecutionEngine = ExecutionEngine()
    optparser = OptionParser()
    optparser.add_option("-v", "--version", action="store_true", dest="showversion",
                         default=False, help="Show the version")
    optparser.add_option("-I", "--include", dest="include", action="append",
                         help="Include path")
    optparser.add_option("-D", dest="define", action="append",
                         default=[], help="Macro Definition")
    optparser.add_option("-B", "--debug", action="store_true", dest="showdebug", help="Debug Mode")
    optparser.add_option("-t", "--top", dest="topmodule",
                         default="top", help="Top module, Default=top")
    optparser.add_option("--nobind", action="store_true", dest="nobind",
                         default=False, help="No binding traversal, Default=False")
    optparser.add_option("--noreorder", action="store_true", dest="noreorder",
                         default=False, help="No reordering of binding dataflow, Default=False")
    optparser.add_option("-o", "--output", dest="outputfile",
                         default="out.png", help="Graph file name, Default=out.png")
    optparser.add_option("-s", "--search", dest="searchtarget", action="append",
                         default=[], help="Search Target Signal")
    optparser.add_option("--sv", action="store_true", dest="sv",
                         default=False, help="enable SystemVerilog parser")
    optparser.add_option("--walk", action="store_true", dest="walk",
                         default=False, help="Walk contineous signals, Default=False")
    optparser.add_option("--identical", action="store_true", dest="identical",
                         default=False, help="# Identical Laef, Default=False")
    optparser.add_option("--step", dest="step", type='int',
                         default=1, help="# Search Steps, Default=1")
    optparser.add_option("--reorder", action="store_true", dest="reorder",
                         default=False, help="Reorder the contineous tree, Default=False")
    optparser.add_option("--delay", action="store_true", dest="delay",
                         default=False, help="Inset Delay Node to walk Regs, Default=False")
    optparser.add_option("--use_cache", action="store_true", dest="use_cache",
                         default=False, help="Use the query caching, Default=False")
    optparser.add_option("--explore_time", help="Time to explore in seconds", dest="explore_time")
    (options, args) = optparser.parse_args()


    num_cycles = args[0]
    filelist = args[1:]

    if options.showversion:
        showVersion()
    
    if options.use_cache:
        engine.cache = redis.Redis(host='localhost', port=6379, db=0)

    timer = None
    if options.explore_time:
        timer = threading.Timer(int(options.explore_time), timeout_exit)
        timer.start()

    if options.showdebug:
        engine.debug = True


    for f in filelist:
        if not os.path.exists(f):
            raise IOError("file not found: " + f)

    # If more than one file, create a .F file listing all files
    if len(filelist) > 1:
        flist_path = "filelist.F"
        with open(flist_path, "w") as flist:
            for f in filelist:
                flist.write(f + "\n")
        filelist = [flist_path]

    if len(filelist) == 0:
        showVersion()
    
    if options.sv:
        start = time.process_time()

        # 1. 初始化 SourceManager (用于管理源代码文件和位置信息)
        source_manager = ps.SourceManager()

        # 2. 配置预处理器 (如果需要 include 路径等，在这里设置)
        pp_options = ps.PreprocessorOptions()
        # pp_options.includePaths = ["./include"]

        bag = ps.Bag([pp_options])

        # 3. 创建 Compilation
        compilation = ps.Compilation(bag)

        # 4. 加载源文件 (支持 .F 文件列表)
        input_file = filelist[0]
        if not os.path.exists(input_file):
            print(f"[Error] File not found: {input_file}")
            exit(1)

        # Check if input is a .F file list
        source_files = []
        if input_file.endswith('.F') or input_file.endswith('.f'):
            # Parse the .F file to get list of source files
            f_file_dir = os.path.dirname(os.path.abspath(input_file))
            with open(input_file, 'r') as f:
                for line in f:
                    line = line.strip()
                    # Skip empty lines and comments
                    if not line or line.startswith('#') or line.startswith('//'):
                        continue
                    # Resolve relative paths relative to the .F file's directory
                    if not os.path.isabs(line):
                        line = os.path.join(f_file_dir, line)
                    source_files.append(line)
            print(f"[Info] Loaded {len(source_files)} files from {input_file}")
        else:
            source_files = [input_file]

        # Load all source files
        for src_file in source_files:
            if not os.path.exists(src_file):
                print(f"[Error] File not found: {src_file}")
                exit(1)
            try:
                # 使用 SourceManager 加载文件，这样报错时能显示文件名和行号
                tree = ps.SyntaxTree.fromFile(src_file, source_manager, bag)
                compilation.addSyntaxTree(tree)
            except Exception as e:
                print(f"[Error] Failed to parse syntax tree for {src_file}: {e}")
                exit(1)

        # 5. 获取模块 (适配 pyslang 9.0+)
        modules = list(compilation.getRoot().topInstances)

        # Also collect all nested module instances
        def collect_all_instances(symbol, collected):
            """Recursively collect all module instances including nested ones"""
            if symbol.kind == ps.SymbolKind.Instance:
                collected.append(symbol)
                # Recursively check children
                for child in symbol.body:
                    collect_all_instances(child, collected)

        all_instances = []
        for top_module in modules:
            collect_all_instances(top_module, all_instances)

        # Use all instances instead of just top instances
        modules = all_instances

        if not modules:
            print("No top instances found, searching syntax trees for definitions...")
            syntax_trees = compilation.getSyntaxTrees()
            for tree in syntax_trees:
                for member in tree.root.members:
                    if hasattr(member, 'kind') and 'ModuleDeclaration' in str(member.kind):
                        modules.append(member)

        # 6. --- 关键修改：正确的错误打印逻辑 ---
        # 获取所有诊断信息
        diags = compilation.getAllDiagnostics()
        
        # 创建诊断引擎和文本客户端
        diag_engine = ps.DiagnosticEngine(source_manager)
        client = ps.TextDiagnosticClient()
        diag_engine.addClient(client)
        
        # 将诊断信息交给引擎处理
        for d in diags:
            diag_engine.issue(d)
            
        # 获取格式化后的错误信息字符串
        report = client.getString()
        
        # 检查是否有 Error 级别的诊断
        has_errors = any(d.isError() for d in diags)
        
        if report:
            print("\n" + "="*40)
            print("COMPILATION DIAGNOSTICS:")
            print("="*40)
            print(report)
            print("="*40 + "\n")
            
        if has_errors:
            print("[Fatal] Compilation failed with errors. See above.")
            exit(1)
            
        if not modules:
            print("[Error] No modules found in the design! (And no syntax errors reported?)")
            exit(1)

        # 7. 编译成功，开始执行符号执行
        successful_compilation = not has_errors
        
        if successful_compilation:
            my_visitor_for_symbol = SymbolicDFS(num_cycles)
            # delegate method from z3Visitor
            my_visitor_for_symbol.expr_to_z3 = lambda m, s, e: parse_expr_to_Z3(e, s, m)

            symbol_visitor = SlangSymbolVisitor() 
            engine.execute_sv(my_visitor_for_symbol, modules, None, num_cycles)
            symbol_visitor.visit(modules)
            print(symbol_visitor.branch_points)
            print(symbol_visitor.paths)
            
        end = time.process_time()
        print(f"Elapsed time {end - start}")
        if timer:
            timer.cancel()
        exit()

if __name__ == '__main__':
    main()
