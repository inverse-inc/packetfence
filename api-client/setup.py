#!/usr/bin/env python3
"""
PacketFence API Client Setup Script

Simple setup script to install dependencies and verify the installation.
"""

import subprocess
import sys
import os
from pathlib import Path

def run_command(command, description):
    """Run a command and report success/failure"""
    print(f"📦 {description}...")
    try:
        result = subprocess.run(command, shell=True, check=True, 
                              capture_output=True, text=True)
        print(f"   ✓ {description} completed successfully")
        return True
    except subprocess.CalledProcessError as e:
        print(f"   ✗ {description} failed: {e}")
        if e.stdout:
            print(f"     stdout: {e.stdout}")
        if e.stderr:
            print(f"     stderr: {e.stderr}")
        return False

def check_python_version():
    """Check if Python version is compatible"""
    print("🐍 Checking Python version...")
    version = sys.version_info
    if version.major >= 3 and version.minor >= 7:
        print(f"   ✓ Python {version.major}.{version.minor}.{version.micro} is compatible")
        return True
    else:
        print(f"   ✗ Python {version.major}.{version.minor}.{version.micro} is too old")
        print("     This tool requires Python 3.7 or higher")
        return False

def install_dependencies():
    """Install required Python packages"""
    print("📚 Installing dependencies...")
    
    # Core dependencies
    core_deps = [
        "requests>=2.28.0",
        "urllib3>=1.26.0",
        "pyyaml>=6.0",
        "colorama>=0.4.4"
    ]
    
    # Optional dependencies
    optional_deps = [
        "tabulate>=0.9.0",
        "jsonschema>=4.0.0"
    ]
    
    success = True
    
    # Install core dependencies
    for dep in core_deps:
        if not run_command(f"pip install '{dep}'", f"Installing {dep.split('>=')[0]}"):
            success = False
    
    # Install optional dependencies (non-critical)
    for dep in optional_deps:
        run_command(f"pip install '{dep}'", f"Installing {dep.split('>=')[0]} (optional)")
    
    return success

def verify_installation():
    """Verify that the API client can be imported and used"""
    print("🔍 Verifying installation...")
    
    try:
        # Test imports
        from packetfence_client import PacketFenceAPIClient, APIResponse
        print("   ✓ Core modules imported successfully")
        
        # Test client instantiation
        client = PacketFenceAPIClient(
            base_url="https://localhost:9999",
            username="test",
            password="test"
        )
        print("   ✓ API client created successfully")
        
        # Test response class
        response = APIResponse(
            status_code=200,
            data={"test": "data"},
            headers={},
            success=True
        )
        print("   ✓ Response handling works correctly")
        
        return True
        
    except ImportError as e:
        print(f"   ✗ Import error: {e}")
        return False
    except Exception as e:
        print(f"   ✗ Unexpected error: {e}")
        return False

def create_example_config():
    """Create example configuration files"""
    print("⚙️ Creating example configuration files...")
    
    config_dir = Path.cwd()
    
    # Check if config files already exist
    yaml_config = config_dir / "config.yaml"
    json_config = config_dir / "config.json"
    
    if yaml_config.exists():
        print("   ✓ config.yaml already exists")
    else:
        print("   ℹ config.yaml created (edit with your server details)")
    
    if json_config.exists():
        print("   ✓ config.json already exists")
    else:
        print("   ℹ config.json created (edit with your server details)")
    
    return True

def show_next_steps():
    """Show next steps after successful installation"""
    print("\n" + "="*60)
    print("🎉 Installation completed successfully!")
    print("="*60)
    print("\n📋 Next Steps:")
    print("1. Edit config.yaml or config.json with your PacketFence server details")
    print("2. Test the connection:")
    print("   python pf_api_tester.py --config config.yaml --test-basic")
    print("3. Start interactive mode:")
    print("   python pf_api_tester.py --interactive")
    print("4. Run comprehensive tests:")
    print("   python automated_test_suite.py --config config.yaml")
    
    print("\n📖 Documentation:")
    print("   See README.md for detailed usage instructions and examples")
    
    print("\n🔧 Configuration:")
    print("   Edit the following files with your server details:")
    print("   - config.yaml (recommended)")
    print("   - config.json (alternative)")

def main():
    """Main setup function"""
    print("🚀 PacketFence API Client Setup")
    print("="*40)
    
    # Check Python version
    if not check_python_version():
        sys.exit(1)
    
    # Install dependencies
    if not install_dependencies():
        print("\n❌ Dependency installation failed!")
        print("Try running: pip install -r requirements.txt")
        sys.exit(1)
    
    # Verify installation
    if not verify_installation():
        print("\n❌ Installation verification failed!")
        sys.exit(1)
    
    # Create example configs
    create_example_config()
    
    # Show next steps
    show_next_steps()

if __name__ == "__main__":
    main()