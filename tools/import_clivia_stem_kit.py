"""Compatibility entry point; see import_stem_kit.py for shared implementation."""
import runpy
from pathlib import Path
runpy.run_path(str(Path(__file__).with_name("import_stem_kit.py")), run_name="__main__")
