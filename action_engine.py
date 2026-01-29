import os
import subprocess
import webbrowser
import platform

import shutil

def execute_command(cmd_string):
    """
    Parses single or chained commands.
    Separator: " and " or " & "
    """
    print(f"Action Engine: Received '{cmd_string}'")
    
    # CHAIN HANDLING
    splitter = " and " if " and " in cmd_string else None
    if not splitter and " & " in cmd_string: splitter = " & "
    
    if splitter:
        parts = cmd_string.split(splitter)
        results = []
        for part in parts:
            success, msg = _execute_single(part.strip())
            results.append(msg)
        return True, " I also ".join(results)
    else:
        return _execute_single(cmd_string)

def _execute_single(cmd_string):
    try:
        if ":" in cmd_string:
            mode, arg = cmd_string.split(":", 1)
            arg = arg.strip()

            if mode == "web":
                if not arg.startswith("http"): arg = "https://" + arg
                webbrowser.open(arg)
                return True, f"Opening {arg}."

            elif mode == "app":
                return _open_app(arg)

            elif mode == "shell":
                subprocess.Popen(arg, shell=True)
                return True, "Executed shell command."
                
    except Exception as e:
        return False, f"Error: {e}"

    return False, "Unknown command."

def _open_app(app_name):
    system = platform.system()
    app_name = app_name.lower()
    
    # 1. COMMON APPS MAP
    common_apps = {
        "calc": ["gnome-calculator", "kcalc", "calc.exe"],
        "notepad": ["gedit", "kate", "notepad.exe"],
        "code": ["code", "code.exe"],
        "files": ["nautilus", "dolphin", "explorer.exe"],
        "terminal": ["gnome-terminal", "konsole", "cmd.exe"]
    }
    
    target_bins = common_apps.get(app_name, [app_name])
    
    # 2. SEARCH PATH
    for bin_name in target_bins:
        if shutil.which(bin_name):
            subprocess.Popen([bin_name] if system == "Linux" else f"start {bin_name}", shell=True)
            return True, f"Opening {app_name}."
            
    # 3. GENERIC LAUNCH
    try:
        if system == "Linux":
            subprocess.Popen(["xdg-open", app_name]) # might fail if not a path/url
        elif system == "Windows":
             subprocess.call(f"start {app_name}", shell=True)
        return True, f"Trying to launch {app_name}..."
    except:
        pass

    return False, f"Could not find application {app_name}."
