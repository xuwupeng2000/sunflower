from pathlib import Path
import tempfile,importlib.util,subprocess,shutil,sys
root=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('check',root/'tests/check.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
tmp=Path(tempfile.mkdtemp(prefix='sunflower-capture-'))
try:
 m.test_project(tmp)
 text=(tmp/'project.godot').read_text().replace('Sunflower Alarm Test','Sunflower Screenshot Capture')
 (tmp/'project.godot').write_text(text)
 (tmp/'scripts').unlink()
 shutil.copytree(root/'scripts',tmp/'scripts')
 store=tmp/'scripts/alarm_store.gd'
 source=store.read_text()
 import re
 source=re.sub(r'func _settings_language\(\) -> String:\n.*?(?=\n\n##)', 'func _settings_language() -> String:\n\treturn str(ProjectSettings.get_setting("screenshots/language", "en"))\n', source, flags=re.S)
 source=source.replace('return OS.is_debug_build() and OS.has_feature("pc")','return false')
 store.write_text(source)
 shutil.copy(Path(__file__).with_name('capture.gd'),tmp/'capture.gd')
 with open('/tmp/sunflower-capture-import.log','w') as log:
  r=subprocess.run([str(m.GODOT),'--headless','--path',str(tmp),'--import','--quit'],stdout=log,stderr=subprocess.STDOUT)
  if r.returncode:raise SystemExit(r.returncode)
 with open('/tmp/sunflower-capture.log','w') as log:
  r=subprocess.run([str(m.GODOT),'--path',str(tmp),'-s','res://capture.gd','--',*sys.argv[1:]],stdout=log,stderr=subprocess.STDOUT)
  raise SystemExit(r.returncode)
finally:shutil.rmtree(tmp,ignore_errors=True)
