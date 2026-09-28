# ThreadBench GDExtension — setup & rebuild notes

A native (C++) GDExtension exposing `ThreadBench.run_sweep(...)` to GDScript,
for comparing real multithreaded performance against GDScript threading.

## One-time setup (already done for this machine)

1. Clone godot-cpp matching your Godot version:
   ```bash
   git clone --recursive --branch 4.5 https://github.com/godotengine/godot-cpp.git
   ```
   Put it as a sibling of `src/` in this folder (i.e. `gdextension_thread_bench/godot-cpp/`).
   **Not committed to git** (30MB+ of generated bindings) — clone fresh if missing.

2. Install SCons: `pip install scons`

3. **If you're on a preview/Insiders Visual Studio** (this machine has
   "VS 2026 Insiders", toolset 14.50) — SCons's own MSVC auto-detection
   fails to recognize it ("No versions of the MSVC compiler were found"),
   and silently falls back to MinGW/g++, which isn't installed, so every
   compile fails with a cryptic "the system cannot find the file specified".
   Fix: apply this patch to `godot-cpp/tools/windows.py`, in `generate()`:

   ```python
   def generate(env):
       if not env["use_mingw"]:                       # was: `and msvc.exists(env)`
           ...
           env["MSVC_SETUP_RUN"] = False
           msvc_script = os.environ.get("SCONS_MSVC_SCRIPT")
           if msvc_script:
               env["MSVC_USE_SCRIPT"] = msvc_script
               env["MSVS_VERSION"] = "14.5"            # placeholder, just needs to parse
           else:
               env["MSVS_VERSION"] = None
   ```

   If you're on a stable (non-preview) Visual Studio release, you likely
   don't need this at all — try building normally first.

## Building

Run `build.ps1` in this folder (uses the workaround above automatically),
or manually:

```powershell
$env:SCONS_MSVC_SCRIPT = "C:\Program Files\Microsoft Visual Studio\18\Insiders\VC\Auxiliary\Build\vcvars64.bat"
cmd /c "`"$env:SCONS_MSVC_SCRIPT`" && python -m SCons platform=windows target=template_debug -j16"
```

Output DLL lands in `bin/`, referenced by `../thread_bench.gdextension`.

## The other gotcha: Godot won't load it until the project has been scanned once

GDExtensions are only registered into `.godot/extension_list.cfg` during a
**project filesystem scan** ("Verifying GDExtensions..." step) — this
normally happens automatically the first time you open the project in the
editor. If you only ever run the project headless/via command line, that
scan never happens, and the extension fails to load **completely silently**
(no error, `ClassDB.class_exists("ThreadBench")` just returns false).

Fix: open the project in the Godot editor once, OR force the scan headlessly:

```bash
godot.exe --headless --editor --quit-after 60 --path "path/to/project"
```

Do this once after adding/changing a `.gdextension` file. After that,
normal headless/exported runs pick it up fine.

## Usage from GDScript

```gdscript
var bench := ThreadBench.new()
var thread_counts := PackedInt32Array([1, 2, 4, 8, 16])
var results: Array = bench.run_sweep(item_count, work_iters, repeats, thread_counts)
# results: Array of {use_calls, threads, time_ms, speedup, efficiency}
```

See `test_native_ext.gd`/`.tscn` at the project root for a full example.
