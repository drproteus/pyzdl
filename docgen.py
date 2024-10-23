import os
import pdoc
import shutil
import pathlib
import tempfile

modules = ["lib"]
files = ["cli.py", "gui.py"]

outdir = "pages/docs"

cwd = os.getcwd()

with tempfile.TemporaryDirectory() as tmpdir:
    moddir = os.path.join(tmpdir, "pyzdl")
    os.makedirs(moddir, exist_ok=True)
    pathlib.Path(os.path.join(moddir, "__ini__.py")).touch()
    for module in modules:
        shutil.copytree(module, os.path.join(moddir, module))
    for file in files:
        shutil.copy(file, os.path.join(moddir, file))

    os.chdir(tmpdir)

    modules = ["pyzdl"]  # Public submodules are auto-imported
    context = pdoc.Context()

    modules = [pdoc.Module(mod, context=context)
            for mod in modules]
    pdoc.link_inheritance(context)

    def recursive_htmls(mod):
        yield mod.name, mod.html()
        for submod in mod.submodules():
            yield from recursive_htmls(submod)

    os.chdir(cwd)

    for mod in modules:
        for module_name, html in recursive_htmls(mod):
            module_name = module_name.replace("pyzdl.", "")
            if module_name == "pyzdl":
                path = os.path.join(outdir, "index.html")
            else:
                module_path = module_name.replace(".", os.path.sep)
                if pathlib.Path(module_path).is_dir():
                    path = os.path.join(outdir, module_path, "index.html")
                else:
                    path = os.path.join(outdir, module_path + ".html")
            os.makedirs(pathlib.Path(path).parent, exist_ok=True)
            with open(path, "w") as f:
                f.write(html)
