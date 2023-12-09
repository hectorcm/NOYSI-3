import requests
from lxml import html
import yaml
import time
import sys

def get_latest_version(package_name):
    url = f"https://pub.dev/packages/{package_name}"
    response = requests.get(url)
    
    if response.status_code == 200:
        tree = html.fromstring(response.content)
        
        # Try both XPath expressions
        version_text = tree.xpath('/html/body/main/div[1]/div[1]/div/div/div/h1/text()')
        if not version_text:
            version_text = tree.xpath('/html/body/main/div[1]/div[2]/div/div/div/h1/text()')
        
        if version_text:
            version_string = version_text[0].strip()
            version_number = version_string.split()[-1]  # Extract the last part (version number)
            return version_number
        else:
            return None  # Package not found
    else:
        return None  # Error fetching package information

def get_dependencies_from_yaml(yaml_path):
    with open(yaml_path, 'r') as file:
        yaml_content = yaml.safe_load(file)

    dependencies = yaml_content.get('dependencies', {})
    return dependencies

# Specify the path to your pubspec.yaml file
pubspec_yaml_path = r'pubspec.yaml'

# Get dependencies from pubspec.yaml
dependencies = get_dependencies_from_yaml(pubspec_yaml_path)

# List of packages to skip with their current versions
packages_to_skip = {
    # "firebase_core": "2.3.0",
    
    # Add more packages to skip as needed
}

# Separate found and not found packages
found_packages = {}
not_found_packages = []

# Emoji loading animation
def emoji_loading_animation():
    emojis = ["🌼", "🌈", "💡", "🚀", "💎"]
    loading_message = "Fetching data from pub.dev..."
    
    for _ in range(20):
        for emoji in emojis:
            sys.stdout.write("\r" + loading_message + " " + emoji)
            sys.stdout.flush()
            time.sleep(0.2)

# Display emoji loading animation
emoji_loading_animation()

# Open a file to write the output
output_file = open('dependencies_output.txt', 'w')

# Fetch the latest versions for each dependency and separate them
for package, version in dependencies.items():
    if package in packages_to_skip:
        found_packages[package] = {"latest_version": packages_to_skip[package], "current_version": version}
        output_file.write(f"{package}: ^{packages_to_skip[package]}\n")
    else:
        latest_version = get_latest_version(package)
        if latest_version is not None:
            found_packages[package] = {"latest_version": latest_version, "current_version": version}
            output_file.write(f"{package}: ^{latest_version}\n")
        else:
            not_found_packages.append(package)

# Close the output file
output_file.close()


# Print found packages
print("Found packages:")
for package, versions in found_packages.items():
    # print(f"{package}: Latest version - {versions['latest_version']}, Current version - {versions['current_version']}")
    print(f"{package}: ^{versions['latest_version']}")

# Print not found packages
print("\nNot found packages:")
for package in not_found_packages:
    print(package)
