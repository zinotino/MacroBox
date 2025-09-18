#!/usr/bin/env python3
"""
MacroMaster Chart Dependencies Installer
Installs required Python packages for data visualization
"""

import subprocess
import sys

def install_package(package):
    """Install a package using pip"""
    try:
        subprocess.check_call([sys.executable, "-m", "pip", "install", package])
        print(f"Successfully installed {package}")
        return True
    except subprocess.CalledProcessError:
        print(f"Failed to install {package}")
        return False

def main():
    """Install all required packages for MacroMaster charts"""
    print("MacroMaster Chart Dependencies Installer")
    print("=" * 50)

    required_packages = [
        "pandas>=1.3.0",
        "plotly>=5.0.0"
    ]

    print("Installing required packages:")
    for package in required_packages:
        print(f"Installing {package}...")
        install_package(package)

    print("\n" + "=" * 50)
    print("Installation complete!")
    print("\nYou can now use interactive charts in MacroMaster.")
    print("Charts will be generated as HTML files and opened in your browser.")

    # Test import
    try:
        import pandas as pd
        import plotly
        print("\nPackage verification successful!")
        print(f"Pandas version: {pd.__version__}")
        print(f"Plotly version: {plotly.__version__}")
    except ImportError as e:
        print(f"\nPackage verification failed: {e}")

if __name__ == "__main__":
    main()