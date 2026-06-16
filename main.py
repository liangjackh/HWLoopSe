"""Lightweight entry point for the symbolic execution engine.

This file handles CLI argument parsing and delegates all work to ExecutionEngine.
"""
from __future__ import absolute_import
from __future__ import print_function
import sys
import os
import threading
import logging
import gc
from optparse import OptionParser

from engine.execution_engine import ExecutionEngine
from engine.config import EngineConfig

gc.collect()

# Setup logging
with open('errors.log', 'w'):
    pass
logging.basicConfig(filename='errors.log', level=logging.DEBUG)
logging.debug("Starting over")

INFO = "Verilog Symbolic Execution Engine"
USAGE = "Usage: python3 -m main <num_cycles> <verilog_file>.v --sv"


def timeout_exit():
    """Exit handler when timer runs out."""
    print("Execution time limit exceeded. Exiting.")
    sys.exit(1)


def show_version():
    """Display version info and exit."""
    print(INFO)
    print(USAGE)
    sys.exit()


def create_option_parser() -> OptionParser:
    """Create and configure the option parser."""
    parser = OptionParser()
    parser.add_option("-v", "--version", action="store_true", dest="showversion",
                      default=False, help="Show the version")
    parser.add_option("-I", "--include", dest="include", action="append",
                      help="Include path")
    parser.add_option("-D", dest="define", action="append",
                      default=[], help="Macro Definition")
    parser.add_option("-B", "--debug", action="store_true", dest="showdebug",
                      help="Debug Mode")
    parser.add_option("-t", "--top", dest="topmodule",
                      default="top", help="Top module, Default=top")
    parser.add_option("--nobind", action="store_true", dest="nobind",
                      default=False, help="No binding traversal, Default=False")
    parser.add_option("--noreorder", action="store_true", dest="noreorder",
                      default=False, help="No reordering of binding dataflow, Default=False")
    parser.add_option("-o", "--output", dest="outputfile",
                      default="out.png", help="Graph file name, Default=out.png")
    parser.add_option("-s", "--search", dest="searchtarget", action="append",
                      default=[], help="Search Target Signal")
    parser.add_option("--sv", action="store_true", dest="sv",
                      default=False, help="Enable SystemVerilog parser")
    parser.add_option("--walk", action="store_true", dest="walk",
                      default=False, help="Walk continuous signals, Default=False")
    parser.add_option("--identical", action="store_true", dest="identical",
                      default=False, help="# Identical Leaf, Default=False")
    parser.add_option("--step", dest="step", type='int',
                      default=1, help="# Search Steps, Default=1")
    parser.add_option("--reorder", action="store_true", dest="reorder",
                      default=False, help="Reorder the continuous tree, Default=False")
    parser.add_option("--delay", action="store_true", dest="delay",
                      default=False, help="Insert Delay Node to walk Regs, Default=False")
    parser.add_option("--use_cache", action="store_true", dest="use_cache",
                      default=False, help="Use the query caching, Default=False")
    parser.add_option("--explore_time", help="Time to explore in seconds",
                      dest="explore_time")
    parser.add_option("--strategy", dest="strategy", default="blind",
                      help="Exploration strategy: blind, directed, or lookahead, Default=blind")
    parser.add_option("--auto-plan", action="store_true", dest="auto_plan",
                      default=False, help="Enable LLM-based milestone generation from assertions")
    parser.add_option("--milestone-file", dest="milestone_file",
                      help="Path to a JSON milestone file (skips LLM generation)")
    parser.add_option("--llm-api-key", dest="llm_api_key",
                      help="API key for LLM (OpenAI, Anthropic, or DeepSeek)")
    parser.add_option("--llm-provider", dest="llm_provider", default="auto",
                      help="LLM provider: openai, anthropic, deepseek, or auto (Default=auto)")
    parser.add_option("--llm-base-url", dest="llm_base_url",
                      help="Custom base URL for LLM API (e.g., https://api.deepseek.com)")
    parser.add_option("--mock", action="store_true", dest="mock",
                      default=False, help="Use mock LLM responses for testing")
    parser.add_option("--coi", action="store_true", dest="coi",
                      default=False, help="Enable Cone of Influence pruning to reduce explored paths")
    parser.add_option("--no-eager-target-eval", action="store_true", dest="no_eager_target_eval",
                      default=False, help="Disable eager final-milestone pre-check (ablation)")
    parser.add_option("--no-sliding-window", action="store_true", dest="no_sliding_window",
                      default=False, help="Disable sliding-window lookahead milestone skip (ablation)")
    return parser


def prepare_filelist(filelist: list) -> str:
    """Prepare input file path, creating .F file if multiple files provided.

    Args:
        filelist: List of input file paths

    Returns:
        Single file path (original or generated .F file)
    """
    for f in filelist:
        if not os.path.exists(f):
            raise IOError(f"file not found: {f}")

    if len(filelist) > 1:
        flist_path = "filelist.F"
        with open(flist_path, "w") as flist:
            for f in filelist:
                flist.write(f + "\n")
        return flist_path

    return filelist[0] if filelist else None


def main():
    """Entry point of the program."""
    # Parse arguments
    parser = create_option_parser()
    options, args = parser.parse_args()

    if options.showversion:
        show_version()

    if len(args) < 2:
        show_version()

    num_cycles = args[0]
    filelist = args[1:]

    # Prepare input file
    input_file = prepare_filelist(filelist)
    if not input_file:
        show_version()

    # Only SystemVerilog mode is supported via the new API
    if not options.sv:
        print("[Error] Only SystemVerilog mode (--sv) is supported.")
        print("Please add --sv flag to your command.")
        sys.exit(1)

    # Create configuration from options
    config = EngineConfig.from_options(options, num_cycles)

    # Setup timeout timer if specified
    timer = None
    if config.explore_time:
        timer = threading.Timer(config.explore_time, timeout_exit)
        timer.start()

    try:
        # Create engine and run
        engine = ExecutionEngine()
        engine.run(input_file, config)
    finally:
        if timer:
            timer.cancel()


if __name__ == '__main__':
    main()
