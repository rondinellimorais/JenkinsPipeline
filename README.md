# JenkinsPipeline
This is a pipeline for build a jobs on command line.

# Authentication

## SSH key pair
By default, this script authenticates with SSH key pair.

### Locating an existing SSH key pair
Before generating a new SSH key check if your system already has one
at the default location by opening a shell, or Command Prompt on Windows,
and running the following command:

##### GNU/Linux / macOS / PowerShell:
```
cat ~/.ssh/id_rsa.pub
```
If you see a string starting with ssh-rsa you already have an SSH key pair
and you can skip the next step **Generating a new SSH key pair**
and continue onto **Copying your public SSH key to the clipboard**.
If you don't see the string or would like to generate a SSH key pair with a
custom name continue onto the next step.

### Generating a new SSH key pair

1. To generate a new SSH key, use the following command:
**GNU/Linux / macOS:**
```
ssh-keygen -t rsa -C "GitLab" -b 4096
```

**Windows:**   
On Windows you will need to download
PuttyGen
and follow this documentation article to generate a SSH key pair.

2. Next, you will be prompted to input a file path to save your key pair to.
If you don't already have an SSH key pair use the suggested path by pressing
enter. Using the suggested path will allow your SSH client
to automatically use the key pair with no additional configuration.

If you already have a key pair with the suggested file path, you will need
to input a new file path and declare what host this key pair will be used
for in your .ssh/config file, see **Working with non-default SSH key pair paths**
for more information.
